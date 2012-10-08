module VisitCounter

  def self.included(base)
    base.class_eval do
      class << self
        #defining class instance attributes
        attr_accessor :visit_counter_threshold, :visit_counter_threshold_method
      end
    end
    base.send(:include, InstanceMethods)
    base.send(:extend, ClassMethods)
  end

  module InstanceMethods
    def incr_counter(name)
      key = VisitCounter::Key.new(self, name)
      set_key = VisitCounter::Key.generate(key.method, key.object_class)
      count = VisitCounter::Store.engine.incr(key.generate_from_instance, Time.now.to_i, set_key)

      staged_count = self.send(:read_attribute, name).to_i
      if Helper.passed_limit?(self, staged_count, count, name)
        Helper.persist(self, staged_count, count, name)
      end
    end

    def get_counter_delta(name)
      key = VisitCounter::Key.new(self, name).generate_from_instance
      VisitCounter::Store.engine.get(key)
    end

    def read_counter(name)
      current_count = self.send(:read_attribute, name).to_i
      count = get_counter_delta(name)

      current_count + count
    end

    def nullify_counter_cache(name, substract = nil)
      key = VisitCounter::Key.new(self, name).generate_from_instance
      if substract
        VisitCounter::Store.engine.substract(key, substract)
      else
        VisitCounter::Store.engine.nullify(key)
      end
    end

  end

  module ClassMethods

    ## override counter threshold. update method counters from the given Time
    ## E.g. Post.update_counters(:num_reads, 1.hour.ago) will all items that received hits in the last hour
    def update_counters(name, from_time_ago)
      set_name = VisitCounter::Key.generate(name, self)
      counters_in_timeframe = VisitCounter::Store.engine.get_all_by_range(set_name, from_time_ago.to_i, Time.now.to_i)
      obj_ids  = counters_in_timeframe.flat_map { |c| [c.split("::")[2].to_i] }
      objects = self.where(id: obj_ids)

      ## if no objects corresponding to the counters were found, remove them.
      counters = Helper.reject_objectless_counters(counters_in_timeframe, objects, obj_ids)

      hits, staged_count = Helper.get_count_stats(counters, objects, name)
      self.transaction do
        objects.zip(Helper.merge_array_values(hits, staged_count)).each do |o|
          VisitCounter::Store.engine.with_lock(o[0]) do
            o[0].class.update_all("#{name} = #{o[1]}", "id = #{o[0].id}")
          end
        end
      end
      VisitCounter::Store.engine.mnullify(counters)
    end

    def cached_counter(name)

      self.send(:define_method, name) do
        read_counter(name)
      end

      self.send(:define_method, "increase_#{name}") do
        incr_counter(name)
      end
    end
  end

  class Helper
    class << self
      def passed_limit?(object, staged_count, diff, name)
        method = object.class.visit_counter_threshold_method || :percent
        threshold = object.class.visit_counter_threshold || default_threshold(method)

        if method.to_sym == :static
          diff >= threshold
        elsif method.to_sym == :percent
          return true if staged_count.to_i == 0
          diff.to_f / staged_count.to_f >= threshold
        end
      end

      def persist(object, staged_count, diff, name)
        VisitCounter::Store.engine.with_lock(object) do
          object.update_attribute(name, staged_count + diff)
          object.nullify_counter_cache(name, diff)
        end
      end

      def default_threshold(method)
        if method.to_sym == :static
          10
        elsif method.to_sym == :percent
          0.3
        end
      end

      def merge_array_values(a1,a2)
        a1.zip(a2).map {|i| i.inject(&:+)}
      end

      def reject_objectless_counters(counters, objects, counter_obj_ids)
        delete_counter_ids = counter_obj_ids - objects.compact.map(&:id)
        counters.reject {|c| delete_counter_ids.include?(c[2])}
      end

      def get_count_stats(counters, objects, name)
        hits = VisitCounter::Store.engine.mget(counters).map(&:to_i)
        staged_count = objects.map {|o| o.send(:read_attribute, name).to_i}
        return hits, staged_count
      end
    end
  end
end
