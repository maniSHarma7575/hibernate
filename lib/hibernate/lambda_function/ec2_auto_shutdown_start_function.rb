require 'aws-sdk-ec2'
require 'json'

def lambda_handler(event:, context:)
  ec2 = Aws::EC2::Client.new

  instance_id = event['instance_id']
  action = event['action']

  begin
    case action
    when 'start'
      ec2.start_instances(instance_ids: [instance_id])
      puts "Started EC2 instance: #{instance_id}"
    when 'stop'
      ec2.stop_instances(instance_ids: [instance_id])
      puts "Stopped EC2 instance: #{instance_id}"
    else
      raise "Invalid action: #{action}. Must be 'start' or 'stop'."
    end
  rescue Aws::EC2::Errors::ServiceError => e
    puts "Error during EC2 action: #{e.message}"
  end
end