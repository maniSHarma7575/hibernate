require 'aws-sdk-ec2'
require 'aws-sdk-cloudwatchevents'
require 'dotenv/load'
require 'json'

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
    @instance_id = get_instance_id_by_name
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
    create_start_rule
    create_stop_rule
    puts "CloudWatch Events created for instance '#{@instance_name}' (ID: #{@instance_id})."
  end

  private

  def create_start_rule
    lambda_function_arn = construct_lambda_function_arn

    @events_client.put_rule({
      name: "StartInstanceRule-#{@instance_id}",
      schedule_expression: "cron(#{@start_cron})",
      state: 'ENABLED',
      description: "Rule to start EC2 instance #{@instance_id} (Name: #{@instance_name}) at specified time: cron(#{@start_cron})",
    })

    @events_client.put_targets({
      rule: "StartInstanceRule-#{@instance_id}",
      targets: [
        {
          id: '1',
          arn: lambda_function_arn,
          input: { instance_id: @instance_id, action: 'start' }.to_json,
        },
      ],
    })
  end

  def create_stop_rule
    lambda_function_arn = construct_lambda_function_arn

    @events_client.put_rule({
      name: "StopInstanceRule-#{@instance_id}",
      schedule_expression: "cron(#{@stop_cron})",
      state: 'ENABLED',
      description: "Rule to stop EC2 instance #{@instance_id} (Name: #{@instance_name}) at specified time: cron(#{@stop_cron})",
    })

    @events_client.put_targets({
      rule: "StopInstanceRule-#{@instance_id}",
      targets: [
        {
          id: '1',
          arn: lambda_function_arn,
          input: { instance_id: @instance_id, action: 'stop' }.to_json,
        },
      ],
    })
  end

  def construct_lambda_function_arn
    "arn:aws:lambda:#{@aws_region}:#{@account_id}:function:#{@lambda_function_name}"
  end
end
