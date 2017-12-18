require 'open-uri'

module ActiveStorage
  class Service::CloudinaryService < Service
    def initialize(cloud_name:, api_key:, api_secret:, options: {})
      Cloudinary.config do |config|
        config.cloud_name = cloud_name
        config.api_key = api_key
        config.api_secret = api_secret
        config.cdn_subdomain = options[:cdn_subdomain] unless options['cdn_subdomain'].nil?
        config.private_cdn = options[:private_cdn] unless options['private_cdn'].nil?
        config.cname = options[:cname] unless options['cname'].nil?
        config.static_image_support = options[:static_image_support] unless options['static_image_support'].nil?
        config.enhance_image_tag = options[:enhance_image_tag] unless options['enhance_image_tag'].nil?
        config.secure = options[:secure] unless options['secure'].nil?
      end
    end

    def upload(key, io, checksum: nil)
      instrument :upload, key: key, checksum: checksum do
        Cloudinary::Uploader.upload(io, public_id: key)
      end
    end

    # Return the content of the file at the +key+.
    # FIXME: Download in chunks when given a block.
    def download(key)
      instrument :download, key: key do
        open(url_for_public_id(key))
      end
    end

    # Delete the file at the +key+.
    def delete(key)
      instrument :delete, key: key do
        delete_resource_with_public_id(key)
      end
    end

    # Delete files at keys starting with the +prefix+.
    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        find_resources_with_public_id_prefix(prefix).each do |resource|
          delete_resource_with_public_id(resource['public_id'])
        end
      end
    end

    # Return +true+ if a file exists at the +key+.
    def exist?(key)
      instrument :exists?, key: key do
        resource_exists_with_public_id(key)
      end
    end

    # Returns a signed, temporary URL for the file at the +key+. The URL will be valid for the amount
    # of seconds specified in +expires_in+. You most also provide the +disposition+ (+:inline+ or +:attachment+),
    # +filename+, and +content_type+ that you wish the file to be served with on request.
    def url(key, _options = {})
      instrument :url, key: key do
        url_for_public_id(key)
      end
    end

    # Returns a signed, temporary URL that a direct upload file can be PUT to on the +key+.
    # The URL will be valid for the amount of seconds specified in +expires_in+.
    # You must also provide the +content_type+, +content_length+, and +checksum+ of the file
    # that will be uploaded. All these attributes will be validated by the service upon upload.
    def url_for_direct_upload(key, options = {})
      instrument :url_for_direct_upload, key: key do
        expires_at = Time.zone.now + options[:expires_in]
        direct_upload_url_for_public_id(key, nil, expires_at: expires_at)
      end
    end

    # Returns a Hash of headers for +url_for_direct_upload+ requests.
    def headers_for_direct_upload(key, _filename:, content_type:, _content_length:, _checksum:)
      { 'Content-Type' => content_type, 'X-Unique-Upload-Id' => key }
    end

    private

    def resource_exists_with_public_id(public_id)
      find_resource_with_public_id(public_id).present?
    end

    def find_resource_with_public_id(public_id)
      Cloudinary::Api.resources_by_ids(public_id).fetch('resources')
    end

    def find_resources_with_public_id_prefix(prefix)
      Cloudinary::Api.resources(type: :upload, prefix: prefix).fetch('resources')
    end

    def delete_resource_with_public_id(public_id)
      Cloudinary::Uploader.destroy(public_id)
    end

    # FIXME: Cloudinary Ruby SDK does't expose an api for signed upload url
    # The expected url is similar to the private_download_url
    # with download replaced with upload
    def direct_upload_url_for_public_id(public_id, format, options)
      # allow the server to auto detect the resource_type
      # if key is not specified, it defaults to 'image'
      options[:resource_type] ||= 'auto'
      Cloudinary::Utils.private_download_url(public_id, format, options).sub(/download/, 'upload')
    end

    def url_for_public_id(public_id)
      Cloudinary::Api.resource(public_id)['secure_url']
    end
  end
end
