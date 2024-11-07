require 'aws-sdk-ec2'
require_relative 'config_loader'

class EC2Client
  def initialize
    aws_credentials = Hibernate::ConfigLoader.new.aws_credentials

    @ec2_client = Aws::EC2::Client.new(
      region: aws_credentials[:region],
      credentials: Aws::Credentials.new(
        aws_credentials[:access_key_id],
        aws_credentials[:secret_access_key]
      )
    )
  end

  def get_instance_name_by_id(instance_id)
    response = @ec2_client.describe_instances({
      instance_ids: [instance_id]
    })

    if response.reservations.empty?
      puts "No instance found with ID '#{instance_id}'."
      return nil
    end

    instance = response.reservations[0].instances[0]
    tags = instance.tags || []

    name_tag = tags.find { |tag| tag.key == 'Name' }
    name_tag&.value
  end

  def get_instance_id_by_name(instance_name)
    response = @ec2_client.describe_instances({
      filters: [
        { name: "tag:Name", values: [instance_name] },
        { name: "instance-state-name", values: ["running", "stopped"] }
      ]
    })

    if response.reservations.empty?
      puts "No EC2 instance found with the name '#{instance_name}'."
      exit 1
    end

    instance_id = response.reservations[0].instances[0].instance_id
    puts "Found EC2 instance ID: #{instance_id} for instance name: #{instance_name}"
    instance_id
  end
end
