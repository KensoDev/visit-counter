require "spec_helper"

class DummyObject
  include VisitCounter

  attr_accessor :counter

  def update_attribute(attribute, value)
    self.send("#{attribute}=", value)
  end

  def read_attribute(name)
    #yeah, evals are evil, but it works and it's for testing purposes only. we assume read_attribute is defined the same as in AR wherever we include this module
    eval("@#{name}")
  end
end

VisitCounter::Store::RedisStore.redis = Redis.new(host: "localhost")

describe VisitCounter do
  describe "incrementing counters" do
    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
    end

    it "should increase the counter from nil / zero using the incr_counter method" do
      @d.counter.should be_nil
      @d.incr_counter(:counter)
      @d.counter.should == 1
    end

    it "should not increase the counter if not passing the threshold" do
      @d.counter = 100
      @d.incr_counter(:counter)
      @d.counter.should == 100
      43.times do
        @d.incr_counter(:counter)
      end
      @d.counter.should == 143

      #should still be 143, because of the percentage thingie
      43.times do
        @d.incr_counter(:counter)
      end
      @d.counter.should == 143
    end
  end

  describe "reading counters" do

    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
    end

    it "should allow to read an unchanged counter" do
      @d.counter = 10
      @d.read_counter(:counter).should == 10
    end

    it "should read an updated counter" do
      @d.counter = 10
      @d.incr_counter(:counter)
      @d.read_counter(:counter).should == 11
    end
  end

  describe "overriding the getter" do
    before :all do
      DummyObject.cached_counter :counter
    end

    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
    end

    it "should define the methods" do
      @d.should respond_to(:increase_counter)
    end

    it "should set the counter" do
      @d.counter = 10
      @d.increase_counter
      @d.counter.should == 11
    end
  end

end