require 'cloudinary'
require 'open-uri'

module ActiveStorage
  class Service::CloudinaryService < Service
    # FIXME: implement setup for private resource type
    # FIXME: allow configuration via cloudinary url
    def initialize(cloud_name:, api_key:, api_secret:, options: {})
      options.merge!(
        cloud_name: cloud_name,
        api_key: api_key,
        api_secret: api_secret
      )
      Cloudinary.config(options)
      # Cloudinary.config_from_url(url)
    end

    def upload(key, io, checksum: nil)
      instrument :upload, key: key, checksum: checksum do
        Cloudinary::Uploader.upload(io, public_id: key)
      end
    end

    # Return the content of the file at the +key+.
    def download(key)
      tmp_file = open(url_for_public_id(key))
      if block_given?
        instrument :streaming_download, key: key do
          File.open(tmp_file, 'rb') do |file|
            while (data = file.read(64.kilobytes))
              yield data
            end
          end
        end
      else
        instrument :download, key: key do
          File.binread tmp_file
        end
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
      instrument :exist?, key: key do
        resource_exists_with_public_id?(key)
      end
    end

    # Returns a signed, temporary URL for the file at the +key+. The URL will be valid for the amount
    # of seconds specified in +expires_in+. You must also provide the +disposition+ (+:inline+ or +:attachment+),
    # +filename+, and +content_type+ that you wish the file to be served with on request.
    def url(key, expires_in:, disposition:, filename:, content_type:)
      instrument :url, key: key do
        options = {
          expires_in: expires_in,
          content_type: content_type,
          disposition: disposition,
          filename: filename
        }
        signed_download_url_for_public_id(key, options)
      end
    end

    # Returns a signed, temporary URL that a direct upload file can be PUT to on the +key+.
    # The URL will be valid for the amount of seconds specified in +expires_in+.
    # You must also provide the +content_type+, +content_length+, and +checksum+ of the file
    # that will be uploaded. All these attributes will be validated by the service upon upload.
    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      instrument :url_for_direct_upload, key: key do
        options = {
          expires_in: expires_in,
          content_type: content_type,
          content_length: content_length,
          checksum: checksum
        }
        direct_upload_url_for_public_id(key, options)
      end
    end

    # Returns a Hash of headers for +url_for_direct_upload+ requests.
    def headers_for_direct_upload(key, filename:, content_type:, content_length:, checksum:)
      { 'Content-Type' => content_type, 'X-Unique-Upload-Id' => key }
    end

    private

    def resource_exists_with_public_id?(public_id)
      !find_resource_with_public_id(public_id).empty?
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

    def url_for_public_id(public_id)
      Cloudinary::Api.resource(public_id)['secure_url']
    end

    # FIXME: Cloudinary Ruby SDK does't expose an api for signed upload url
    # The expected url is similar to the private_download_url
    # with download replaced with upload
    def direct_upload_url_for_public_id(public_id, options)
      # allow the server to auto detect the resource_type
      options[:resource_type] ||= 'auto'
      signed_download_url_for_public_id(public_id, options).sub(/download/, 'upload')
    end

    def signed_download_url_for_public_id(public_id, options)
      options[:resource_type] ||= resource_type(options[:content_type])
      Cloudinary::Utils.private_download_url(
        public_id,
        resource_format(options),
        signed_url_options(options)
      )
    end

    def signed_url_options(options)
      {
        resource_type: (options[:resource_type] || 'auto'),
        type: (options[:type] || 'upload'),
        attachment: (options[:attachment] == :attachment),
        expires_at: (Time.now + options[:expires_in])
      }
    end

    def resource_format(_options); end

    def resource_type(content_type)
      content_type.sub(%r{/.*$}, '')
    end
  end
end
