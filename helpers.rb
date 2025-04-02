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
    'APP_STORE_CONNECT_ISSUER_ID',
    'APP_STORE_CONNECT_KEY_CONTENT'
  ]

  missing_vars = required_env_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
  
  unless missing_vars.empty?
    UI.user_error!("Missing required environment variables: #{missing_vars.join(', ')}")
  end
end