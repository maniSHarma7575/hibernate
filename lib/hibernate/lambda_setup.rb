require 'aws-sdk-lambda'
require 'aws-sdk-iam'
require 'zip'
require 'fileutils'
require 'pry'
require_relative 'config_loader'

class LambdaSetup
  def initialize
    config_loader = Hibernate::ConfigLoader.new
    @aws_region = config_loader.aws_credentials[:region]

    @lambda_role_name = "ec2-auto-shutdown-start"
    @lambda_handler = "ec2_auto_shutdown_start_function"
    @lambda_zip = "lambda_function.zip"
    @iam_client = Aws::IAM::Client.new(
      region: @aws_region,
      access_key_id: config_loader.aws_credentials[:access_key_id],
      secret_access_key: config_loader.aws_credentials[:secret_access_key]
    )

    @lambda_client = Aws::Lambda::Client.new(
      region: @aws_region,
      access_key_id: config_loader.aws_credentials[:access_key_id],
      secret_access_key: config_loader.aws_credentials[:secret_access_key]
    )
  end

  def create_zip_file(dir)
    FileUtils.rm_f(@lambda_zip)

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

  def iam_role_exists?(role_name)
    begin
      @iam_client.get_role(role_name: role_name)
      true
    rescue Aws::IAM::Errors::NoSuchEntity
      false
    end
  end

  def create_lambda_role
    unless iam_role_exists?(@lambda_role_name)
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

      puts "Creating IAM role..."
      @iam_client.create_role({
        role_name: @lambda_role_name,
        assume_role_policy_document: trust_policy
      })

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

      puts "Attaching custom EC2 policy to IAM role..."
      @iam_client.put_role_policy({
        role_name: @lambda_role_name,
        policy_name: "EC2ControlPolicy",
        policy_document: policy_document
      })

      @iam_client.attach_role_policy({
        role_name: @lambda_role_name,
        policy_arn: 'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
      })

      puts "IAM role created and policies attached."
    else
      puts "IAM role '#{@lambda_role_name}' already exists. Skipping role creation."
    end
  end

  def lambda_function_exists?(function_name)
    begin
      @lambda_client.get_function(function_name: function_name)
      true
    rescue Aws::Lambda::Errors::ResourceNotFoundException
      false
    end
  end

  def create_lambda_function
    role_arn = @iam_client.get_role(role_name: @lambda_role_name).role.arn

    if lambda_function_exists?(@lambda_handler)
      puts "Lambda function '#{@lambda_handler}' already exists. Skipping creation."
    else
      zip_content = File.read(@lambda_zip)

      begin
        puts "Creating Lambda function..."
        @lambda_client.create_function({
          function_name: @lambda_handler,
          runtime: 'ruby3.2',
          role: role_arn,
          handler: "#{@lambda_handler}.lambda_handler",
          code: {
            zip_file: zip_content,
          },
          description: 'Lambda function to start and stop EC2 instances',
          timeout: 30
        })
        puts "Lambda function created."
      rescue Aws::Lambda::Errors::ServiceError => e
        puts "Error creating Lambda function: #{e.message}"
      end
    end
  end

  def run
    create_zip_file('lambda_function')
    create_lambda_role
    create_lambda_function
  end
end
