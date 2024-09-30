require 'aws-sdk-ec2'
require 'aws-sdk-cloudwatch'
require 'dotenv'
require 'json'

Dotenv.load

module Hibernate
  require_relative 'hibernate/version'
end
