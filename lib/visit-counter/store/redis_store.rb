require "redis"

module VisitCounter
  class Store
    class RedisStore < VisitCounter::Store::AbstractStore
      @@redis = nil
      class << self

        def redis=(r)
          @@redis = ::Redis.new(r)
        end

        def redis
          @@redis
        end

        def incr(key)
          redis.incr(key).to_i
        end

        def get(key)
          redis.get(key).to_i
        end

        def nullify(key)
          redis.set(key, 0)
        end

      end
    end
  end
end