require 'aws-sdk-lambda'
require 'aws-sdk-iam'   # For creating the IAM role and policy
require 'zip'
require 'dotenv/load'   # Automatically loads environment variables from .env
require 'fileutils'
require 'pry'

class LambdaSetup
  def initialize
    @lambda_role_name = "ec2-auto-shutdown-start"  # Define a unique role name
    @lambda_handler = "ec2_auto_shutdown_start_function"
    @lambda_zip = "lambda_function.zip"
    @aws_region = ENV['AWS_REGION']
    @iam_client = Aws::IAM::Client.new(region: @aws_region)
    @lambda_client = Aws::Lambda::Client.new(
      region: @aws_region,
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
  end

  # Function to zip the Lambda function code
  def create_zip_file(dir)
    FileUtils.rm_f(@lambda_zip)  # Remove any existing zip file

    Zip::File.open(@lambda_zip, Zip::File::CREATE) do |zip|
      Dir.glob(File.join('lib', 'hibernate',dir, '**', '*')).each do |file|
        next if File.directory?(file)
        zip_path = File.basename(file)
        puts "Adding #{file} as #{zip_path}"
        File.open(file, 'rb') do |io|
          zip.add(zip_path, io)
        end
      end
    end

    puts "ZIP file created: #{@lambda_zip}"
  end

  # Function to check if an IAM role exists
  def iam_role_exists?(role_name)
    begin
      @iam_client.get_role(role_name: role_name)
      true  # Role exists
    rescue Aws::IAM::Errors::NoSuchEntity
      false  # Role does not exist
    end
  end

  # Function to create the IAM role and policy
  def create_lambda_role
    unless iam_role_exists?(@lambda_role_name)
      # Trust policy for Lambda service to assume this role
      trust_policy = {
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Principal: {
              Service: "lambda.amazonaws.com"
            },
            Action: "sts:AssumeRole"
          }
        ]
      }.to_json

      # Create the IAM role
      puts "Creating IAM role..."
      @iam_client.create_role({
        role_name: @lambda_role_name,
        assume_role_policy_document: trust_policy
      })

      # Define the custom policy for EC2 actions
      policy_document = {
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Action: [
              "ec2:DescribeInstances",
              "ec2:StartInstances",
              "ec2:StopInstances"
            ],
            Resource: "*"
          }
        ]
      }.to_json

      # Attach custom policy to the IAM role
      puts "Attaching custom EC2 policy to IAM role..."
      @iam_client.put_role_policy({
        role_name: @lambda_role_name,
        policy_name: "EC2ControlPolicy",
        policy_document: policy_document
      })

      # Attach basic execution role to allow CloudWatch logging
      @iam_client.attach_role_policy({
        role_name: @lambda_role_name,
        policy_arn: 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
      })

      puts "IAM role created and policies attached."
    else
      puts "IAM role '#{@lambda_role_name}' already exists. Skipping role creation."
    end
  end

  # Function to check if the Lambda function exists
  def lambda_function_exists?(function_name)
    begin
      @lambda_client.get_function(function_name: function_name)
      true  # Lambda function exists
    rescue Aws::Lambda::Errors::ResourceNotFoundException
      false  # Lambda function does not exist
    end
  end

  # Function to create the Lambda function
  def create_lambda_function
    role_arn = @iam_client.get_role(role_name: @lambda_role_name).role.arn

    if lambda_function_exists?(@lambda_handler)
      puts "Lambda function '#{@lambda_handler}' already exists. Skipping creation."
    else
      # Read the ZIP file as binary content
      zip_content = File.read(@lambda_zip)

      # Create Lambda function
      begin
        puts "Creating Lambda function..."
        @lambda_client.create_function({
          function_name: @lambda_handler,
          runtime: 'ruby3.2',  # Specify your desired runtime
          role: role_arn,  # Use the ARN of the newly created role
          handler: "#{@lambda_handler}.lambda_handler",
          code: {
            zip_file: zip_content,
          },
          description: 'Lambda function to start and stop EC2 instances',
          timeout: 30,
        })
        puts "Lambda function created."
      rescue Aws::Lambda::Errors::ServiceError => e
        puts "Error creating Lambda function: #{e.message}"
      end
    end
  end

  # Main method to execute the setup
  def run
    create_zip_file('lambda_function')  # Pass the directory containing your Lambda function code
    create_lambda_role
    create_lambda_function
  end
end