require "spec_helper"

class DummyObject
  include VisitCounter

  attr_accessor :counter, :persist_with_callbacks

  def update_attribute(attribute, value)
    self.send("#{attribute}=", value)
  end

  def save
    nil
  end  

  def read_attribute(name)
    #yeah, evals are evil, but it works and it's for testing purposes only. we assume read_attribute is defined the same as in AR wherever we include this module
    eval("@#{name}")
  end
end

VisitCounter::Store::RedisStore.redis = Redis.new(host: "localhost")
VisitCounter::Store::RedisStore.redis.flushdb

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
      VisitCounter::Store.engine.should_receive(:with_lock)
      VisitCounter::Helper.persist(@d, 1, 1, :counter)
    end

    it "should not persist if object is locked" do
      VisitCounter::Store.engine.stub!(:acquire_lock).and_return(false)
      @d.should_not_receive(:update_attribute)
      VisitCounter::Helper.persist(@d, 1, 1, :counter)
    end

    it "should persist if object is locked" do
      VisitCounter::Store.engine.stub!(:acquire_lock).and_return(true)
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
  
  describe "persist with callbacks" do
    it "should use save method" do
      @d = DummyObject.new
      @d.class.persist_with_callbacks = true
      @d.stub!(:id).and_return(1)
      @d.should_receive(:save)
      @d.incr_counter :counter
    end  
  end  

  describe "updating counters for the given time-period (disregarding threshold)" do
    let(:d_key) {"visit_counter::DummyObject::1::counter"}
    let(:d1_key) {"visit_counter::DummyObject::2::counter"}
    let(:set_name) {"visit_counter::DummyObject::counter"}

    before :each do
      @d, @d1 = DummyObject.new, DummyObject.new
      @d.stub(:id).and_return(1)
      @d1.stub(:id).and_return(2)
      DummyObject.stub(:transaction).and_yield
      @d.nullify_counter_cache(:counter)
      VisitCounter::Store.engine.redis.del set_name
      @d.increase_counter
      @d1.increase_counter
    end

    it "should update multiple objects" do
      DummyObject.stub(:where).and_return([@d, @d1])
      DummyObject.should_receive(:update_all).once.with("counter = 1", "id = 1").ordered
      DummyObject.should_receive(:update_all).once.with("counter = 1", "id = 2").ordered
      DummyObject.update_counters(:counter, (Time.now - 4))
    end

    it "should only find counter hits from the given time-period" do
      VisitCounter::Store.engine.redis.zincrby(set_name, -100000, d1_key)
      VisitCounter::Store.engine.get_all_by_range(set_name, (Time.now - 20).to_i, Time.now.to_i).should == [d_key]
    end

    it "should not try to update counters without objects" do
      VisitCounter::Store.engine.should_receive(:get_all_by_range).and_return([d_key, d1_key])
      DummyObject.stub(:where).and_return([@d])
      VisitCounter::Helper.stub(:merge_array_values).and_return([0])
      DummyObject.should_receive(:update_all).once
      DummyObject.update_counters(:counter, (Time.now - 4))
    end
  end

end
