# ActiveStorage::Service::CloudinaryService

With **v5.2**, Rails introduces [ActiveStorage](https://github.com/rails/rails/blob/master/activestorage/README.md), to facilitate uploading files to cloud services and attaching those files to ActiveRecord objects. Out of the box, it comes with implementations for cloud storage services; Amazon S3, Google Cloud Storage, and Microsoft Azure Storage; with an extendible adapter for adding support for other storage services.

This gem extends the ActiveStorage::Service api with an implementation for [Cloudinary](https://cloudinary.com/) cloud service. The implementation is a thin wrapper around the official [cloudinary gem](https://github.com/cloudinary/cloudinary_gem) to provide necessary interfaces required to hook up cloudinary to the active_storage api. Serving as a middleman, it interprets active_storage requests and delegate to their cloudinary gem contemporary and parses the response as necessary. So you can work with Cloudinary much like you would any of the other active_storage services that comes out of the box.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cloudinary', require: false
gem 'activestorage-cloudinary-service'
```

And then execute:

    $ bundle

## Usage

In your Rails 5.2+ app, run:
```shell
  rails active_storage:install
```
This copy's over the active_storage migration for creating the needed tables and then run:
```shell
  rails db:migrate
```

_Note: you can skip the above two steps if you already have active_storage setup or if working a new Rails 5.2 (the setup is automatically added)_

Declare a Cloudinary service in `config/storage.yml`. Each active_storage service requires a `name` and the relevant configurations options. Basic configuration options for cloudinary are `cloud_name`, `api_key` and `api_secret`. These are available from your [cloudinary account dashboard](https://cloudinary.com/console/cloudinary.yml).

```yaml
cloudinary:
  service: Cloudinary
  cloud_name: <%= ENV['CLOUDINARY_CLOUD_NAME'] %>
  api_key:    <%= ENV['CLOUDINARY_API_KEY'] %>
  api_secret: <%= ENV['CLOUDINARY_API_SECRET'] %>
```

The env vars should correspond to their appropriate values as defined in your app. Or using `rails credentials:edit` to set the cloudinary secrets `(as cloudinary:cloud_name|api_key|api_secret)`
```yaml
cloudinary:
  service: Cloudinary
  cloud_name: <%= Rails.application.credentials.dig(:cloudinary, :cloud_name) %>
  api_key: <%= Rails.application.credentials.dig(:cloudinary, :api_key) %>
  api_secret: <%= Rails.application.credentials.dig(:cloudinary, :api_secret) %>
```

*See [here](https://cloudinary.com/documentation/api_and_access_identifiers) for other supported configurations options that can be provided.*

Tell Active Storage to use the Cloudinary service by setting `Rails.application.config.active_storage.service`. It is recommended to do this on a per-environment basis to enjoy the flexibility of using different services for different environment.

For example, to use the cloudinary service in the production environment, you would add the following to `config/environments/production.rb`

```rb
config.active_storage.service = :cloudinary
```

## Known issues
Currently, active_storage client-side upload doesn't work with Cloudinary. This because the cloudinary api doesn't, as at now, support the `PUT` request method used by [activestorage.js](https://github.com/rails/rails/blob/master/activestorage/app/javascript/activestorage/blob_upload.js#L9) library and as such client side uploads will error out with the message `Method PUT is not allowed by Access-Control-Allow-Methods in preflight response.`

Nevertheless, the necessary ground work for this is set and once either active_storage is updated to support more request type or Cloudinary enables support for `PUT` request method, it should work fine.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/0sc/activestorage-cloudinary-service. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveStorage::Service::CloudinaryService project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/0sc/activestorage-cloudinary-service/blob/master/CODE_OF_CONDUCT.md).
