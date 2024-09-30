# my_gem.gemspec
require_relative 'lib/hibernate/version'

Gem::Specification.new do |spec|
  spec.name          = "hibernate"
  spec.version       = Hibernate::VERSION
  spec.summary       = "Automating the shutdown and start of our EC2 instances"
  spec.description   = "A Ruby gem to automate the shutdown and start of our EC2 instances"
  spec.authors       = ["Manish Sharma"]
  spec.email         = ["sharma.manish7575@gmail.com"]
  spec.homepage      = "https://github.com/maniSHarma7575/hibernate"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"]

  spec.executables   = ["hibernate"]
  spec.require_paths  = ["lib"]

  # Specify runtime dependencies
  spec.add_dependency "aws-sdk-ec2"
  spec.add_dependency "aws-sdk-cloudwatch"
  spec.add_dependency "dotenv"
  spec.add_dependency "json"
  spec.add_dependency "rubyzip"

  # Specify development dependencies (optional)
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"

  spec.metadata = {
    "source_code_uri" => "https://github.com/maniSHarma7575/hibernate",
    "homepage_uri"    => "https://github.com/maniSHarma7575/hibernate",
    "bug_tracker_uri" => "https://github.com/maniSHarma7575/hibernate/issues"
  }
end
