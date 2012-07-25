module VisitCounter
  class Store
    @@engine ||= VisitCounter::Store::Redis

    def self.set_engine(store)
      @@engine = store
    end
    
  end
end