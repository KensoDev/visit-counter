module VisitCounter
  class Key

    attr_reader :object, :method
    def initialize(object, method)
      @object = object
      @method = method
    end

    def self.generate(method, obj_class, obj_id = nil)
      ["visit_counter", obj_class, obj_id, method].compact.join("::")
    end

    def generate_from_instance
      object_class = self.object_class
      Key.generate(method,object_class, self.object.id)
    end

    def object_class
      object.class.to_s
    end
  end
end
