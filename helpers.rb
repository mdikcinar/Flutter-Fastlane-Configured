# Helper method to read version and build number from pubspec.yaml
require 'yaml'

def get_flutter_version
  pubspec = YAML.load_file('../../pubspec.yaml')
  version = pubspec['version']
  version_number, build_number = version.split('+')
  return version_number
end

# Validation helpers
def validate_build_options(options)
  UI.user_error!("Missing flavor") unless options[:flavor]
  UI.user_error!("Missing target") unless options[:target]
end

def validate_ios_build_options(options)
  UI.user_error!("Missing app_name") unless options[:app_name]
  UI.user_error!("Missing scheme") unless options[:scheme]
end

def validate_app_store_credentials
  required_env_vars = [
    'APP_STORE_CONNECT_KEY_IDENTIFIER',
    'APP_STORE_CONNECT_ISSUER_ID'
  ]

  missing_vars = required_env_vars.select { |var| ENV[var].to_s.strip.empty? }

  key_present = !ENV['APP_STORE_CONNECT_PRIVATE_KEY'].to_s.strip.empty?
  key_path_present = !ENV['APP_STORE_CONNECT_PRIVATE_KEY_PATH'].to_s.strip.empty?

  unless key_present || key_path_present
    missing_vars << 'APP_STORE_CONNECT_PRIVATE_KEY or APP_STORE_CONNECT_PRIVATE_KEY_PATH'
  end

  unless missing_vars.empty?
    UI.user_error!("Missing required environment variables: #{missing_vars.join(', ')}")
  end
end

def fetch_app_store_private_key_content
  key_content = ENV['APP_STORE_CONNECT_PRIVATE_KEY']
  return key_content unless key_content.to_s.strip.empty?

  key_path = ENV['APP_STORE_CONNECT_PRIVATE_KEY_PATH']
  return nil if key_path.to_s.strip.empty?

  expanded_path = File.expand_path(key_path.strip, __dir__)
  unless File.exist?(expanded_path)
    UI.user_error!("APP_STORE_CONNECT_PRIVATE_KEY_PATH does not exist at #{expanded_path}")
  end

  File.read(expanded_path)
end

def option_enabled?(value)
  return false if value.nil?

  if value.is_a?(String)
    normalized = value.strip.downcase
    return true if %w[true yes 1].include?(normalized)
    return false if %w[false no 0].include?(normalized)
  end

  value == true
end
