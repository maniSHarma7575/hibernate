# EC2 Auto Shutdown and Start

As a software engineering team, we are working with Amazon EC2 instances on a daily basis While EC2 instances are great for running applications and services but its important to properly manage our instances to avoid unnecessary costs and resource consumption. One way to do this is by automating the shutdown and start of your EC2 instances

This project automates the start and stop of AWS EC2 instances based on scheduled CloudWatch Events using an AWS Lambda function. It leverages Ruby AWS SDK for creating the Lambda function, CloudWatch Events, and EC2 instance management. You can configure the instance and schedule using the CLI.

## Project Overview

The project allows you to:
- Create a Lambda function that automatically starts or stops EC2 instances based on their current state (i.e., running or stopped).
- Schedule EC2 instance start/stop operations using CloudWatch Events.
- Manage the schedule and EC2 instance operations through a Ruby-based CLI.

```mermaid
flowchart TB
    A[User - Command Line Interface]
    B[CloudWatch Events]
    C[Lambda Function]
    D{Start or Stop EC2 Instance?}
    E[Start EC2 Instance]
    F[Stop EC2 Instance]
    G[CloudWatch Logs]

    subgraph AWS Cloud
        B
        C
        D
        E
        F
        G
    end

    A -->|Configure CloudWatch Events| B
    B -->|Trigger Event| C
    C -->|Execute Script| D
    D -->|Start| E
    D -->|Stop| F
    C -->|Log Execution| G
    A -.->|Monitor Logs| G

    classDef default fill:#f7f7f7,stroke:#2c3e50,stroke-width:2px;
    classDef input fill:#3498db,stroke:#2c3e50,stroke-width:2px,color:#fff;
    classDef process fill:#1abc9c,stroke:#2c3e50,stroke-width:2px,color:#fff;
    classDef decision fill:#f39c12,stroke:#2c3e50,stroke-width:2px;
    classDef output fill:#2ecc71,stroke:#2c3e50,stroke-width:2px,color:#fff;
    classDef storage fill:#e74c3c,stroke:#2c3e50,stroke-width:2px,color:#fff;

    class A input;
    class B,C process;
    class D decision;
    class E,F output;
    class G storage;
```

## Features

- **Lambda function**: Automatically manages the start and stop of EC2 instances.
- **CloudWatch Events**: Schedules based on cron expressions to run the Lambda function at specific times.
- **CLI Interface**: Easy-to-use interface for setting up the Lambda function and managing EC2 instance operations.

---

## Prerequisites

- **AWS CLI**: Ensure that the AWS CLI is installed and configured with access to your AWS account.
- **Ruby 3.x**: The project requires Ruby version 3.x. Install Ruby using a version manager like RVM or rbenv.
- **AWS SDK for Ruby**: The project uses `aws-sdk-ec2` and `aws-sdk-cloudwatchevents` gems.
- **IAM Permissions**: Ensure the AWS user you are using has permissions to:

Required IAM Permissions

1. CloudWatch Events Permissions

	- events:PutRule – To create or update CloudWatch event rules.
	- events:ListRules – To list existing event rules.
	- events:DescribeRule – To get details about a specific event rule.
	- events:PutTargets – To associate targets with the CloudWatch event rules.
	- events:RemoveTargets – To remove targets from CloudWatch event rules.
	- events:DeleteRule – To delete an event rule.
	- events:ListTargetsByRule – To list targets associated with a specific rule.

2. EC2 Permissions

	- ec2:DescribeInstances – To retrieve information about EC2 instances.
	- ec2:StartInstances – To start EC2 instances (if applicable).
	- ec2:StopInstances – To stop EC2 instances (if applicable).

3. Lambda Permissions

	- lambda:AddPermission – To allow CloudWatch Events to invoke the Lambda function.
	- lambda:RemovePermission – To remove permissions allowing invocation of the Lambda function.
	- lambda:InvokeFunction – To allow invocation of the specified Lambda function (if it’s needed directly).

4. IAM Permissions

	- iam:PassRole – If the Lambda function requires a role, this permission allows passing a role to the Lambda service.

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"events:PutRule",
				"events:ListRules",
				"events:DescribeRule",
				"events:PutTargets",
				"events:RemoveTargets",
				"events:DeleteRule",
				"events:ListTargetsByRule"
			],
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"ec2:DescribeInstances",
				"ec2:StartInstances",
				"ec2:StopInstances"
			],
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"lambda:AddPermission",
				"lambda:RemovePermission",
				"lambda:InvokeFunction",
				"lambda:CreateFunction",
				"lambda:GetFunction"
			],
			"Resource": "arn:aws:lambda:<region>:<account-id>:function:*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"iam:GetRole",
				"iam:PassRole",
				"lambda:GetFunction"
			],
			"Resource": [
				"arn:aws:iam::<account-id>:role/<role-name>",
				"arn:aws:iam::<account-id>:role/*",
				"arn:aws:lambda:<region>:<account-id>:function:<function-name>"
			]
		}
	]
}
```

---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone [https://github.com/maniSHarma7575/hibernate.git](https://github.com/maniSHarma7575/hibernate.git)
cd hibernate
```

### 2. Install Dependencies

Make sure you have the required gems by running:

```bash
bundle install
```

### 3. Environment Configuration

Create a `.env` file at the root of your project and configure your AWS credentials:

```bash
AWS_ACCESS_KEY_ID=<your-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
AWS_REGION=<your-aws-region>
ACCOUNT_ID=<your-account-id>
```

---

## Usage

The project includes a CLI to manage the setup of the Lambda function and CloudWatch Events. Here’s how you can use it:

### 1. Setup the Lambda Function

Run the following command to set up the Lambda function:

```bash
bin/hibernate setup
```

This command will:
- Create an IAM role (if it doesn't exist).
- Create the Lambda function.
- Attach the necessary permissions for managing EC2 instances.

### 2. Manage EC2 Instances with Scheduled Start/Stop

Use the following command to create or update rules for EC2 instances with scheduled start/stop times:

```bash
bin/hibernate rule --create --instance-name=<instance_name> --start-expression="<cron>" --stop-expression="<cron>"
```

- `--instance-name=<instance_name>`: The EC2 instance name tag.
- `--start-expression=<cron>`: The cron expression for when to start the instance.
- `--stop-expression=<cron>`: The cron expression for when to stop the instance.

Both `--start-expression` and `--stop-expression` are optional, but at least one must be provided.

#### Example:

```bash
bin/hibernate rule --create --instance-name="hibernate" --start-expression="55 9 * * ? *" --stop-expression="50 9 * * ? *"
```

This schedules the instance named "hibernate" to start at 9:55 AM UTC and stop at 9:50 AM UTC.

### 3. List Scheduled Start/Stop Rules

To list all scheduled start/stop rules for all EC2 instances:

```bash
bin/hibernate rule --list
```

To list rules for a specific EC2 instance or filter by start/stop rules:

```bash
bin/hibernate rule --list [--instance-name=<instance_name>] [--start-instance=true] [--stop-instance=true]
```

Parameters:
- `--instance-name=<instance_name>`: The name tag of the EC2 instance whose rules you want to list (optional).
- `--start-instance=true`: (Optional) Include this flag to list only the start rules.
- `--stop-instance=true`: (Optional) Include this flag to list only the stop rules.

#### Examples:

```bash
bin/hibernate rule --list --instance-name=hibernate
bin/hibernate rule --list --start-instance=true
```

### 4. Update Existing Rules

To update an existing rule:

```bash
bin/hibernate rule --update --rule=<rule_name> [--start-expression="<new_cron>"] [--stop-expression="<new_cron>"] [--state=<new_state>]
```

- `--rule=<rule_name>`: The name of the rule to update.
- `--start-expression="<new_cron>"`: (Optional) The new cron expression for starting the instance.
- `--stop-expression="<new_cron>"`: (Optional) The new cron expression for stopping the instance.
- `--state=<new_state>`: (Optional) The new state of the rule. Use "enable" to enable the rule or "disable" to disable it.

#### Example:

```bash
bin/hibernate rule --update --rule=StartInstanceRule-i-0ad52c31c25c659aa-9afb6fd6 --start-expression="20 12 * * ? *"
```

This updates the start rule to trigger at 12:20 PM UTC.

Disable a rule:

```bash
bin/hibernate rule --update --rule=StopInstanceRule-i-0ad52c31c25c659aa-d1751fc4 --state=disable
```

### 5. Remove Scheduled Start/Stop Rules

Use the following command to remove a specific rule:

```bash
bin/hibernate rule --remove --rule-name=<rule_name>
```

- `--rule-name=<rule_name>`: Specify the rule you want to delete.

#### Example:

```bash
bin/hibernate rule --remove --rule-name=StartInstanceRule-i-0ad52c31c25c659aa-b0716de3
```

This will remove the specified CloudWatch rule.

### Cron Expressions in AWS CloudWatch Events

CloudWatch Events uses the following format for cron expressions:

```
cron(Minutes Hours Day-of-month Month Day-of-week Year)
```

- **Example**: `cron(55 9 * * ? *)` runs every day at 9:55 AM UTC.

### Summary of Commands

- **Setup Lambda**: `bin/hibernate setup`
- **Create/Update Rule**: `bin/hibernate rule --create --instance-name=<instance_name> --start-expression=<cron> --stop-expression=<cron>`
- **List Rules**: `bin/hibernate rule --list [--instance-name=<instance_name>] [--start-instance=true] [--stop-instance=true]`
- **Update Rule**: `bin/hibernate rule --update --rule=<rule_name> [--start-expression=<new_cron>] [--stop-expression=<new_cron>] [--state=<new_state>]`
- **Remove Rule**: `bin/hibernate rule --remove --rule-name=<rule_name>`

---

### Resources:
- [AWS Cron Expressions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html)

## Contributing

Feel free to submit pull requests or report issues. We welcome contributions to enhance the functionality of the project.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

### Final Notes

- Ensure your AWS credentials are properly configured in the `.env` file.
- Test the Lambda function thoroughly before deploying it to production environments.
