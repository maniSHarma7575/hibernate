require 'aws-sdk-cloudwatchevents'
require 'json'

class CloudWatchEventManager
  def initialize(events_client, instance_id, instance_name, lambda_function_arn)
    @events_client = events_client
    @instance_id = instance_id
    @instance_name = instance_name
    @lambda_function_arn = lambda_function_arn
  end

  def create_start_rule(cron_expression)
    create_rule(
      "StartInstanceRule-#{@instance_id}",
      cron_expression,
      { instance_id: @instance_id, action: 'start' },
      "start"
    )
  end

  def create_stop_rule(cron_expression)
    create_rule(
      "StopInstanceRule-#{@instance_id}",
      cron_expression,
      { instance_id: @instance_id, action: 'stop' },
      "stop"
    )
  end

  private

  def create_rule(rule_name, cron_expression, input_data, action)
    @events_client.put_rule({
      name: rule_name,
      schedule_expression: "cron(#{cron_expression})",
      state: 'ENABLED',
      description: "Rule to #{action} EC2 instance #{@instance_id} (Name: #{@instance_name}) at specified time: cron(#{cron_expression})",
    })

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
end
