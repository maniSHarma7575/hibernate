require 'yaml'

module Hibernate
  class ConfigLoader
    def initialize(config_path = 'config.yaml')
      @config_path = config_path
      @config = load_config
      @profile = ENV['AWS_PROFILE'] || default_profile
      validate_config
    end

    def aws_credentials
      account_config = @config.dig('aws_accounts', @profile)

      if account_config.nil?
        raise "Profile #{@profile} not found in the configuration file."
      end

      {
        account_id: account_config['account_id'],
        region: account_config['region'],
        access_key_id: account_config.dig('credentials', 'access_key_id'),
        secret_access_key: account_config.dig('credentials', 'secret_access_key')
      }
    end

    private

    def load_config
      if File.exist?(@config_path)
        YAML.load_file(@config_path)
      else
        raise "Configuration file not found: #{@config_path}"
      end
    end

    def validate_config
      unless @config.dig('aws_accounts', @profile)
        raise "Profile #{@profile} is not defined in the configuration file."
      end

      credentials = @config.dig('aws_accounts', @profile, 'credentials')
      unless credentials && credentials['access_key_id'] && credentials['secret_access_key']
        raise "AWS credentials for profile #{@profile} are missing or incomplete."
      end
    end

    def default_profile
      default_accounts = @config['aws_accounts'].select { |_, account| account['default'] }
      if default_accounts.empty?
        raise "No default profile found in the configuration."
      end
      default_accounts.keys.first
    end
  end
end
