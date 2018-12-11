
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_storage/service/version'

Gem::Specification.new do |spec|
  spec.name          = 'activestorage-cloudinary-service'
  spec.version       = ActiveStorage::CloudinaryService::VERSION
  spec.authors       = ['Osmond Oscar']
  spec.email         = ['oskarromero3@gmail.com']

  spec.summary       = 'Rails ActiveStorage adapter for cloudinary'
  spec.homepage      = 'https://github.com/0sc/activestorage-cloudinary-service'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'pry', '~> 0.11.3'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.7'
end
