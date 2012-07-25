module VisitCounter
  def incr_counter(counter_name)
    count = VisitCounter::Store.incr(VisitCounter::Key.key(self, counter_name))
  end
end