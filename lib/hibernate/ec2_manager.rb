require 'aws-sdk-ec2'
require 'dotenv/load'
require 'json'
require_relative 'cloud_watch_event_manager' # Adjust the path to where the new class is located

class EC2Manager
  def initialize(instance_name, start_cron, stop_cron)
    @instance_name = instance_name
    @start_cron = start_cron
    @stop_cron = stop_cron
    @aws_region = ENV['AWS_REGION']
    @account_id = ENV['ACCOUNT_ID']

    @ec2_client = Aws::EC2::Client.new(region: @aws_region)
    @events_client = Aws::CloudWatchEvents::Client.new(region: @aws_region)

    @lambda_function_name = "ec2_auto_shutdown_start_function"
    @lambda_function_arn = construct_lambda_function_arn
    @instance_id = get_instance_id_by_name

    @cloudwatch_event_manager = CloudWatchEventManager.new(@events_client, @instance_id, @instance_name, @lambda_function_arn)
  end

  def get_instance_id_by_name
    response = @ec2_client.describe_instances({
      filters: [
        { name: "tag:Name", values: [@instance_name] },
        { name: "instance-state-name", values: ["running", "stopped"] }
      ]
    })

    if response.reservations.empty?
      puts "No EC2 instance found with the name '#{@instance_name}'."
      exit 1
    end

    instance_id = response.reservations[0].instances[0].instance_id
    puts "Found EC2 instance ID: #{instance_id} for instance name: #{@instance_name}"
    instance_id
  end

  def create_event_rule
    @cloudwatch_event_manager.create_start_rule(@start_cron)
    @cloudwatch_event_manager.create_stop_rule(@stop_cron)
    puts "CloudWatch Events created for instance '#{@instance_name}' (ID: #{@instance_id})."
  end

  private

  def construct_lambda_function_arn
    "arn:aws:lambda:#{@aws_region}:#{@account_id}:function:#{@lambda_function_name}"
  end
end
