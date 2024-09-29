# my_gem.gemspec

Gem::Specification.new do |spec|
  spec.name          = "hibernate"  # Name of the gem
  spec.version       = "0.1.0"        # Initial version
  spec.summary       = "Manage EC2 instances with Lambda functions"  # Short description
  spec.description   = "A Ruby gem to automate the management of EC2 instances using AWS Lambda."  # Long description
  spec.authors       = ["Your Name"]   # Author(s)
  spec.email         = ["youremail@example.com"]  # Author's email
  spec.homepage      = "https://github.com/yourusername/ec2_manager"  # Homepage URL
  spec.license       = "MIT"           # License type

  # Specify the files to include in the gem package
  spec.files         = Dir["lib/**/*.rb"] + Dir["README.md"]  # Include all Ruby files in lib and the README

  # Specify executables (optional)
  spec.executables   = ["hibernate"]   # Name of the executable
  spec.require_paths  = ["lib"]        # Load paths

  # Specify runtime dependencies
  spec.add_dependency "aws-sdk-ec2"
  spec.add_dependency "aws-sdk-cloudwatch"
  spec.add_dependency "dotenv"
  spec.add_dependency "json"
  spec.add_dependency "rubyzip"

  # Specify development dependencies (optional)
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
end