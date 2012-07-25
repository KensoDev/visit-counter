module VisitCounter
  class Key
    def self.key(object, method)
      "visit_counter::#{object.class.to_s}::#{object.id}::#{method}"
    end
  end
end