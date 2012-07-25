require "spec_helper"

describe VisitCounter::Store do
  
  describe "engine" do
    it "should have the redis store by default" do
      VisitCounter::Store.engine.should == VisitCounter::Store::RedisStore
    end

    it "should be able to change the storage engine" do
      VisitCounter::Store.set_engine(VisitCounter::Store::RailsStore)
      VisitCounter::Store.engine.should == VisitCounter::Store::RailsStore

      #switching back
      VisitCounter::Store.set_engine(VisitCounter::Store::RedisStore)
    end
  end

end