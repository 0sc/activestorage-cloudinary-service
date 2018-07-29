module ActiveStorage
  class Service
    def instrument(_operation, _option = {})
      yield
    end
  end
end

module DummyCloudinary
  class << self
    %i[cloud_name api_key api_secret cname upload_preset].each do |mtd|
      attr_accessor mtd
    end

    def config(options)
      options.each { |k, v| send("#{k}=", v) }
    end
  end

  class Uploader
    def self.upload(_file, _options = {}); end

    def self.destroy(_key); end
  end

  class Api
    def self.resources(_options); end

    def self.resources_by_ids(_public_id); end

    def self.delete_resources_by_prefix(_prefix); end
  end

  class Downloader
    def self.download(_key); end
  end

  class Utils
    def self.private_download_url(_public_id, _format, _options); end

    def self.resource_type_for_format(ext)
      %w[png pdf].include?(ext) ? 'image' : 'raw'
    end

    def self.cloudinary_url(key)
      "https://#{key}"
    end
  end
end

require 'active_storage/service/cloudinary_service'
