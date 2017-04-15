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

        ## adding keys to sorted sets, to allow searching by timstamp(score).
        ## subsequent hits to the same key will only update the timestamp (and won't duplicate).
        def incr(key, timestamp, set_name)
          redis.zadd(set_name, timestamp, key)
          redis.incr(key).to_i
        end

        def del(key)
          redis.del(key)
        end

        def get(key)
          redis.get(key).to_i
        end

        def mget(keys)
          redis.mget(*keys).map(&:to_i)
        end

        def nullify(key)
          redis.set(key, 0)
        end

        def mnullify(keys)
          keys_with_0 = keys.flat_map {|k| [k,"0"]}
          redis.mset(*keys_with_0)
        end

        ## Usage: to get all post#num_reads counters in the last hour, do:
        ## redis.zrangebyscore("visit-counter::Post::num_reads", (Time.now - 3600).to_i, Time.now.to_i)
        def get_all_by_range(sorted_set_key, min, max)
          redis.zrangebyscore(sorted_set_key, min, max)
        end

        def substract(key, by)
          redis.decrby(key, by)
        end

        def acquire_lock(object)
          redis.setnx(lock_key(object), 1)
        end

        def unlock!(object)
          redis.del(lock_key(object))
        end

        def lock_key(object)
          "#{object.class.name.downcase}_#{object.id}_object_cache_lock"
        end

        def with_lock(object, &block)
          if acquire_lock(object)
            begin
              yield
            ensure
              unlock!(object)
            end
          end
        end
      end
    end
  end
end
