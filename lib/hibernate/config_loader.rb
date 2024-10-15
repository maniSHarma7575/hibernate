require 'yaml'
require 'fileutils'

module Hibernate
  class ConfigLoader
    CACHE_FILE_PATH = File.expand_path('~/.aws_account_cache')

    def initialize(config_path = 'config.yaml')
      @config_path = config_path
      @account_id = fetch_account_id
      @config = load_config
      validate_config
    end

    def aws_credentials
      account_config = @config.dig('aws_accounts', @account_id)
      if account_config.nil?
        raise "Account ID #{@account_id} not found in the configuration file."
      end

      {
        account_id: @account_id,
        region: account_config['region'],
        access_key_id: account_config.dig('credentials', 'access_key_id'),
        secret_access_key: account_config.dig('credentials', 'secret_access_key')
      }
    end

    def self.cache_account_id(account_id)
      FileUtils.mkdir_p(File.dirname(CACHE_FILE_PATH)) # Ensure directory exists
      File.write(CACHE_FILE_PATH, account_id)
    end

    private

    def fetch_account_id
      if ENV['AWS_ACCOUNT_ID']
        self.class.cache_account_id(ENV['AWS_ACCOUNT_ID'])
        ENV['AWS_ACCOUNT_ID']
      elsif File.exist?(CACHE_FILE_PATH)
        File.read(CACHE_FILE_PATH).strip
      else
        raise "AWS account ID is not set. Please pass an account ID using the --account-id option or set it in the configuration."
      end
    end

    def load_config
      if File.exist?(@config_path)
        YAML.load_file(@config_path)
      else
        raise "Configuration file not found: #{@config_path}"
      end
    end

    def validate_config
      unless @config.dig('aws_accounts', @account_id)
        raise "Please set the 'account_id' in the configuration file."
      end

      credentials = @config.dig('aws_accounts', @account_id, 'credentials')
      unless credentials && credentials['access_key_id'] && credentials['secret_access_key']
        raise "AWS credentials for account ID #{@account_id} are missing or incomplete."
      end
    end
  end
end
