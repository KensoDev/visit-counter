module VisitCounter

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.send(:extend, ClassMethods)
  end

  module InstanceMethods
    def incr_counter(name)
      key = VisitCounter::Key.key(self, name)
      count = VisitCounter::Store.engine.incr(key)
      current_count = self.send(:read_attribute, name).to_i
      if current_count / (current_count + count).to_f < 0.7
        self.update_attribute(name, current_count + count)
        nullify_counter_cache(name)
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

    def nullify_counter_cache(name)
      key = VisitCounter::Key.key(self, name)
      VisitCounter::Store.engine.nullify(key)
    end
  end

  module ClassMethods

    def cached_counter(name)
      self.send(:alias_method, "real_#{name}", name)

      self.send(:define_method, name) do
        read_counter(name)
      end

      self.send(:define_method, "increase_#{name}") do
        incr_counter(name)
      end
    end

  end
end