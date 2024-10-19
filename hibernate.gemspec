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

  spec.files         = `git ls-files`.split($\)
  spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.bindir        = 'bin'
  spec.require_paths  = ["lib"]

  spec.required_ruby_version = '>= 3.2.2'

  spec.add_dependency "aws-sdk-ec2", "~> 1.478"
  spec.add_dependency "aws-sdk-cloudwatch", "~> 1.103"
  spec.add_dependency "aws-sdk-lambda", "~> 1.136"
  spec.add_dependency "aws-sdk-cloudwatchevents", "~> 1.83"
  spec.add_dependency "aws-sdk-iam", "~> 1.111"

  spec.add_dependency "dotenv", "~> 3.1"
  spec.add_dependency "json", "~> 2.7"
  spec.add_dependency "rubyzip", "~> 2.3"
  spec.add_dependency "optimist", "~> 3.1"

  # Specify development dependencies
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.66"

  spec.metadata = {
    "source_code_uri" => "https://github.com/maniSHarma7575/hibernate",
    "bug_tracker_uri" => "https://github.com/maniSHarma7575/hibernate/issues"
  }

  spec.requirements << 'Git'
end
