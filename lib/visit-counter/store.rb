module VisitCounter
  class Store
    @@engine ||= VisitCounter::Store::RedisStore

    class << self

      def set_engine(store)
        @@engine = store
      end

      def engine
        @@engine
      end

    end
    
  end
end