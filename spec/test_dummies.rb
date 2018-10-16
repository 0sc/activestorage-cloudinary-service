module ActiveStorage
  class Service
    def instrument(_operation, _option = {})
      yield
    end
  end
end

require 'active_storage/service/cloudinary_service'
