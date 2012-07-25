module VisitCounter
  class Store
    class AbstractStore
      class << self
        #placeholders

        def incr(key)
          raise NotImplementedError
        end

        def get(key)
          raise NotImplementedError
        end

        def nullify(key)
          raise NotImplementedError
        end
      end
    end
  end
end