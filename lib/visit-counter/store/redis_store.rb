require "redis"

module VisitCounter
  class Store
    class RedisStore < VisitCounter::Store::AbstractStore
      @@redis = nil
      class << self

        def redis=(r)
          if r.is_a?(Redis)
            @@redis = r
          else
            @@redis = Redis.new(r)
          end
        end

        def redis
          if @@redis.nil? && defined?($redis)
            @@redis = $redis
          else
            @@redis
          end
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

        def substract(key, by)
          redis.decrby(key, by)
        end

        def aquire_lock!(object)
          redis.setnx(lock_key(object), 1)
        end

        def unlock!(object)
          redis.del(lock_key(object))
        end

        def lock_key(object)
          "#{object.class.name.downcase}_#{object.id}_object_cache_lock"
        end

        def with_lock(object, &block)
          if aquire_lock!(object)
            result = yield
            unlock!(object)
            result
          end
        end

      end
    end
  end
end