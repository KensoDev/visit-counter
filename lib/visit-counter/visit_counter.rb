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
      key = VisitCounter::Key.key(self, name)
      count = VisitCounter::Store.engine.incr(key)
      staged_count = self.send(:read_attribute, name).to_i
      if Helper.passed_limit?(self, staged_count, count, name)
        Helper.persist(self, staged_count, count, name)
      end
    end

    def get_counter_delta(name)
      key = VisitCounter::Key.key(self, name)
      VisitCounter::Store.engine.get(key)
    end

    def read_counter(name)
      current_count = self.send(:read_attribute, name).to_i
      count = get_counter_delta(name)

      current_count + count
    end

    def nullify_counter_cache(name, substract = nil)
      key = VisitCounter::Key.key(self, name)
      if substract
        VisitCounter::Store.engine.substract(key, substract)
      else
        VisitCounter::Store.engine.nullify(key)
      end
    end
  end

  module ClassMethods

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

    end
  end
end