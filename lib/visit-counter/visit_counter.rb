module VisitCounter
  def incr_counter(name)
    key = VisitCounter::Key.key(self, name)
    count = VisitCounter::Store.engine.incr(key)
    current_count = self.send(name).to_i
    if current_count / (current_count + count).to_f < 0.7
      self.update_attribute(name, current_count + count)
      nullify_counter_cache(name)
    end
  end

  def read_counter(name)
    key = VisitCounter::Key.key(self, name)
    current_count = self.send(name).to_i
    count = VisitCounter::Store.engine.get(key)

    current_count + count
  end

  def nullify_counter_cache(name)
    key = VisitCounter::Key.key(self, name)
    VisitCounter::Store.engine.nullify(key)
  end
end