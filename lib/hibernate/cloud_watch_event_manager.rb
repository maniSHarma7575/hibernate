require 'aws-sdk-cloudwatchevents'
require 'json'
require 'dotenv/load'
require 'digest'
require_relative 'config_loader'
require_relative 'ec2_client'

class CloudWatchEventManager
  def initialize(events_client, instance_id = nil, instance_name = nil, lambda_function_arn)
    config_loader = Hibernate::ConfigLoader.new
    @events_client = events_client
    @instance_id = instance_id
    @instance_name = instance_name
    @lambda_function_arn = lambda_function_arn
    @aws_region = config_loader.aws_credentials[:region]
    @account_id = config_loader.aws_credentials[:account_id]
    @lambda_client = Aws::Lambda::Client.new(
      region: @aws_region,
      access_key_id: config_loader.aws_credentials[:access_key_id],
      secret_access_key: config_loader.aws_credentials[:secret_access_key]
    )

    @ec2_client = EC2Client.new
  end

  attr_writer :instance_id, :instance_name

  def create_start_rule(cron_expression)
    rule_name = "StartInstanceRule-#{@instance_id}-#{cron_expression_hash(cron_expression)}"
    create_rule(
      rule_name,
      cron_expression,
      { instance_id: @instance_id, action: 'start' },
      'start'
    )
  end

  def create_stop_rule(cron_expression)
    rule_name = "StopInstanceRule-#{@instance_id}-#{cron_expression_hash(cron_expression)}"
    create_rule(
      rule_name,
      cron_expression,
      { instance_id: @instance_id, action: 'stop' },
      'stop'
    )
  end

  def remove_rule(rule_name)
    remove_rule_by_name(rule_name)
    remove_lambda_permission(rule_name)
  end

  def list_event_rules(options)
    next_token = nil

    column_widths = {
      rule_name: 50,
      instance_id: 22,
      instance_name: 40,
      schedule: 30,
      state: 10,
      action: 10
    }

    print_header(column_widths)

    loop do
      response = @events_client.list_rules(next_token: next_token)

      response.rules.each do |rule|
        process_rule(rule, options, column_widths)
      end

      next_token = response.next_token
      break if next_token.nil?
    end

    print_footer(column_widths)
  end

  def update_rule_state(rule_name, state)
    state = state == 'enable' ? 'ENABLED' : 'DISABLED'

    rule_details = @events_client.describe_rule({ name: rule_name })

    params = {
      name: rule_name,
      state: state,
      description: rule_details.description
    }

    if rule_details.schedule_expression
      params[:schedule_expression] = rule_details.schedule_expression
    elsif rule_details.event_pattern
      params[:event_pattern] = rule_details.event_pattern
    else
      puts "No ScheduleExpression or EventPattern found for rule '#{rule_name}'."
      exit 1
    end
  
    @events_client.put_rule(params)
  end

  def get_instance_id_from_rule(rule_name)
    response = @events_client.list_targets_by_rule({ rule: rule_name })
    return nil if response.targets.empty?

    target_input = response.targets[0].input
    parsed_input = JSON.parse(target_input)
    parsed_input['instance_id'] if parsed_input.key?('instance_id')
  rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException => e
    puts "Error fetching targets for rule: #{rule_name} - #{e.message}"
    nil
  end

  def rule_exists?(rule_name)
    begin
      response = @events_client.describe_rule({ name: rule_name })
      return true unless response.nil?
    rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
      return false
    end
  end

  private

  def cron_expression_hash(cron_expression)
    Digest::SHA256.hexdigest(cron_expression)[0..7] 
  end

  def create_rule(rule_name, cron_expression, input_data, action)
    @events_client.put_rule({
      name: rule_name,
      schedule_expression: "cron(#{cron_expression})",
      state: 'ENABLED',
      description: "Rule to #{action} EC2 instance #{@instance_id} (Name: #{@instance_name}) at specified time: cron(#{cron_expression})",
    })

    add_lambda_permission(rule_name)

    @events_client.put_targets({
      rule: rule_name,
      targets: [
        {
          id: '1',
          arn: @lambda_function_arn,
          input: input_data.to_json,
        },
      ],
    })

    puts "#{action.capitalize} rule created for instance '#{@instance_name}' (ID: #{@instance_id})."
  end

  def add_lambda_permission(rule_name)
    begin
      @lambda_client.add_permission({
        function_name: @lambda_function_arn,
        statement_id: "#{rule_name}-Permission",
        action: "lambda:InvokeFunction",
        principal: "events.amazonaws.com",
        source_arn: "arn:aws:events:#{@aws_region}:#{@account_id}:rule/#{rule_name}"
      })

      puts "Permission added for rule #{rule_name} to invoke Lambda #{@lambda_function_arn}."
    rescue Aws::Lambda::Errors::ResourceConflictException => e
      puts "Permission already exists: #{e.message}"
    end
  end

  def remove_rule_by_name(rule_name)
    @events_client.remove_targets({
      rule: rule_name,
      ids: ['1']
    })
    @events_client.delete_rule({
      name: rule_name
    })

    puts "Removed rule '#{rule_name}'"
  end

  def remove_lambda_permission(rule_name)
    begin
      @lambda_client.remove_permission({
        function_name: @lambda_function_arn,
        statement_id: "#{rule_name}-Permission"
      })
      puts "Removed Lambda permission for rule '#{rule_name}' to invoke Lambda #{@lambda_function_arn}."
    rescue Aws::Lambda::Errors::ResourceNotFoundException => e
      puts "Permission not found: #{e.message}"
    end
  end

  def print_header(column_widths)
    total_width = column_widths.values.sum + 8
    puts "-" * total_width
    puts "| #{'Rule Name'.ljust(column_widths[:rule_name])} | " \
         "#{ 'Instance ID'.ljust(column_widths[:instance_id])} | " \
         "#{ 'Instance Name'.ljust(column_widths[:instance_name])} | " \
         "#{ 'Schedule (UTC)'.ljust(column_widths[:schedule])} | " \
         "#{ 'State'.ljust(column_widths[:state])} | " \
         "#{ 'Action'.ljust(column_widths[:action])} |"
    puts "-" * total_width
  end

  def print_footer(column_widths)
    total_width = column_widths.values.sum + 8
    puts '-' * total_width
  end

  def process_rule(rule, options, column_widths)
    targets = @events_client.list_targets_by_rule(rule: rule.name).targets
    target = targets.find { |t| t.arn == @lambda_function_arn }

    return unless target

    input = JSON.parse(target.input)
    action = input['action']
    rule_instance_id = input['instance_id']

    instance_name = @ec2_client.get_instance_name_by_id(rule_instance_id)
    if matches_criteria?(rule_instance_id, action, options)
      print_rule(rule, rule_instance_id, instance_name, action, column_widths)
    end
  end

  def matches_criteria?(rule_instance_id, action, options)
    instance_id_match = options[:instance_id].nil? || options[:instance_id] == rule_instance_id
    action_match = (options[:start] && action == 'start') ||
                   (options[:stop] && action == 'stop') ||
                   (options[:start].nil? && options[:stop].nil?) ||
                   ((!options[:start].nil? && !options[:stop].nil?) && (!options[:start] && !options[:stop]))

    instance_id_match && action_match
  end

  def print_rule(rule, rule_instance_id, instance_name, action, column_widths)
    puts "| #{rule.name.ljust(column_widths[:rule_name])} | " \
         "#{rule_instance_id.ljust(column_widths[:instance_id])} | " \
         "#{instance_name.ljust(column_widths[:instance_name])} | " \
         "#{rule.schedule_expression.ljust(column_widths[:schedule])} | " \
         "#{rule.state.ljust(column_widths[:state])} | " \
         "#{action.capitalize.ljust(column_widths[:action])} |"
  end
end
