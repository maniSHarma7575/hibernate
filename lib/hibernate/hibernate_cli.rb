class HibernateCli
  def self.setup_profile(profile)
    ENV['AWS_PROFILE'] = profile
  end

  def self.create_lambda_function
    LambdaSetup.new.run
  end

  def self.handle_rule_subcommand(subcmd, options)
    case subcmd
    when 'create'
      create_ec2_rule_command(options)
    when 'list'
      list_ec2_rule_command(options)
    when 'update'
      update_ec2_rule_command(options)
    when 'remove'
      remove_ec2_rule_command(options)
    end
  end

  def self.create_ec2_rule_command(options)
    validate_options(options, %i[instance_name], 'create')
    ec2_manager = EC2Manager.new(options[:instance_name])
    ec2_manager.create_event_rule(options[:start], options[:stop])
  end

  def self.list_ec2_rule_command(options)
    ec2_manager = EC2Manager.new(options[:instance_name])
    ec2_manager.list_event_rules(options)
  end

  def self.update_ec2_rule_command(options)
    validate_options(options, %i[rule], 'update')
    ec2_manager = EC2Manager.new(options[:instance_name])
    ec2_manager.update_event_rule(
      rule_name: options[:rule],
      start_cron: options[:start],
      stop_cron: options[:stop],
      state: options[:state]
    )
  end

  def self.remove_ec2_rule_command(options)
    validate_options(options, [:rule], 'remove')
    ec2_manager = EC2Manager.new(options[:instance_name])
    ec2_manager.remove_event_rule(options[:rule])
  end

  private

  def self.validate_options(options, required_fields, command)
    missing_fields = required_fields.select { |field| options[field].nil? }
    return if missing_fields.empty?

    puts "Please provide #{missing_fields.join(', ')}."
    puts "Usage: hibernate rule --#{command} #{required_fields.map { |field| "--#{field.to_s.tr('_', '-')}" }.join(' ')}"
    exit
  end
end

