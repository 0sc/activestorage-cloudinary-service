module ActiveStorage
  class Service
    def instrument(_operation, _option = {})
      yield
    end
  end
end

module DummyCloudinary
  class << self
    %i[cloud_name api_key api_secret].each do |mtd|
      attr_accessor mtd
    end

    def config
      yield(self)
    end
  end

  class Uploader
    def self.upload(_file, _options = {}); end

    def self.destroy(_key); end
  end

  class Api
    def self.resources(_options); end

    def self.resources_by_ids(_public_id); end
  end

  class Utils
    def self.private_download_url(_public_id, _format, _options); end
  end
end

require 'active_storage/service/cloudinary_service'
