require 'aws-sdk-ec2'
require 'dotenv/load'
require 'json'
require_relative 'cloud_watch_event_manager' # Adjust the path to where the new class is located
require_relative 'config_loader'
require_relative 'ec2_client'

class EC2Manager
  def initialize(instance_name = nil)
    @instance_name = instance_name
    aws_credentials = Hibernate::ConfigLoader.new.aws_credentials

    @aws_region = aws_credentials[:region]
    @account_id = aws_credentials[:account_id]
    @ec2_client = EC2Client.new

    @events_client = Aws::CloudWatchEvents::Client.new(
      region: @aws_region,
      credentials: Aws::Credentials.new(
        aws_credentials[:access_key_id],
        aws_credentials[:secret_access_key]
      )
    )

    @lambda_function_name = "ec2_auto_shutdown_start_function"
    @lambda_function_arn = construct_lambda_function_arn
    @instance_id = @instance_name ? @ec2_client.get_instance_id_by_name(@instance_name) : nil

    @cloudwatch_event_manager = CloudWatchEventManager.new(
      @events_client, @instance_id, @instance_name, @lambda_function_arn
    )
  end

  attr_writer :instance_name, :instance_id

  def create_event_rule(start_cron, stop_cron)
    @cloudwatch_event_manager.create_start_rule(start_cron) unless start_cron.nil?
    @cloudwatch_event_manager.create_stop_rule(stop_cron) unless stop_cron.nil?
    puts "CloudWatch Events created for instance '#{@instance_name}' (ID: #{@instance_id})."
  end

  def remove_event_rule(rule_name)
    @cloudwatch_event_manager.remove_rule(rule_name)
    puts "CloudWatch Events removed for rule: #{rule_name}."
  end

  def list_event_rules(options)
    options[:instance_id] = @instance_id unless @instance_id.nil?
    @cloudwatch_event_manager.list_event_rules(options)
  end

  def update_event_rule(rule_name:, start_cron:, stop_cron:, state:)
    rule_exists = @cloudwatch_event_manager.rule_exists?(rule_name)

    unless rule_exists
      puts "Rule '#{rule_name}' does not exist."
      exit 1
    end

    target_instance_id = @cloudwatch_event_manager.get_instance_id_from_rule(rule_name)
    if target_instance_id.nil?
      puts "No targets found for the rule '#{rule_name}'."
      exit 1
    end

    instance_name = @ec2_client.get_instance_name_by_id(target_instance_id)

    @cloudwatch_event_manager.instance_id = target_instance_id
    @cloudwatch_event_manager.instance_name = instance_name

    self.instance_id = target_instance_id
    self.instance_name = instance_name

    puts "Found instance ID: #{@instance_id} from the rule: #{rule_name}"

    if start_cron || stop_cron
      puts "Removing old rule: #{rule_name} as cron expression is being updated."
      remove_event_rule(rule_name)

      create_event_rule(start_cron, stop_cron)
      puts "Created new rule with updated cron expression for instance '#{@instance_name}' (ID: #{@instance_id})."
    end

    return if state.nil?

    @cloudwatch_event_manager.update_rule_state(rule_name, state)
    puts "Rule '#{rule_name}' has been #{state == 'enable' ? 'enabled' : 'disabled'}."
  end

  private

  def construct_lambda_function_arn
    "arn:aws:lambda:#{@aws_region}:#{@account_id}:function:#{@lambda_function_name}"
  end
end
