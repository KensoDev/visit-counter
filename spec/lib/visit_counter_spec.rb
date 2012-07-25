require "spec_helper"

class DummyObject
  include VisitCounter

  attr_accessor :counter

  def update_attribute(attribute, value)
    self.send("#{attribute}=", value)
  end
end

VisitCounter::Store::RedisStore.redis = {host: "localhost"}

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
end