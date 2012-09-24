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
      30.times do
        @d.incr_counter(:counter)
      end
      @d.counter.should == 130

      #should still be 143, because of the percentage thingie
      30.times do
        @d.incr_counter(:counter)
      end
      @d.counter.should == 130
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

  describe "static threshold" do
    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
      DummyObject.visit_counter_threshold_method = :static
    end

    it "should persist after setting a static threshold of 1" do
      DummyObject.visit_counter_threshold = 1
      @d.counter = 10
      @d.incr_counter(:counter)
      @d.counter.should == 11
    end

    it "should not persist after setting a static threshold of 2" do
      DummyObject.visit_counter_threshold = 2
      @d.counter = 10
      @d.incr_counter(:counter)
      @d.counter.should == 10

      @d.incr_counter(:counter)
      @d.counter.should == 12
    end
  end

  describe "percent threshold" do
    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
      DummyObject.visit_counter_threshold_method = :percent
    end

    it "should persist when passing a percent" do
      DummyObject.visit_counter_threshold = 0.1
      @d.counter = 10
      @d.incr_counter(:counter)
      @d.counter.should == 11
    end
  end

  describe "locked objects" do
    before :each do
      @d = DummyObject.new
      @d.stub!(:id).and_return(1)
      @d.nullify_counter_cache(:counter)
    end

    it "should lock object when updating" do
      VisitCounter::Helper.should_receive(:lock)
      VisitCounter::Helper.persist(@d, 1, 1, :counter)
    end

    it "should not persist if object is locked" do
      VisitCounter::Store.engine.stub!(:locked?).and_return(true)
      @d.should_not_receive(:update_attribute)
      VisitCounter::Helper.persist(@d, 1, 1, :counter)
    end

    it "should persist if object is locked" do
      VisitCounter::Store.engine.stub!(:locked?).and_return(false)
      @d.should_receive(:update_attribute)
      VisitCounter::Helper.persist(@d, 1, 1, :counter)
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