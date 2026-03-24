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

def read_option_file(path_value, label:)
  expanded_path = File.expand_path(path_value, __dir__)
  unless File.exist?(expanded_path)
    UI.user_error!("#{label} file does not exist at #{expanded_path}")
  end

  File.read(expanded_path)
end

def resolve_text_option(options, direct_key:, path_key:, label:)
  direct_value = options[direct_key].to_s.strip
  path_value = options[path_key].to_s.strip

  return direct_value unless direct_value.empty?
  return nil if path_value.empty?

  read_option_file(path_value, label: label).strip
end

def normalize_localized_build_info(value, label:)
  UI.user_error!("#{label} must be a Hash keyed by locale") unless value.is_a?(Hash)

  value.each_with_object({}) do |(locale, info), normalized|
    locale_key = locale.to_s.strip
    UI.user_error!("#{label} contains an empty locale key") if locale_key.empty?

    whats_new_value = if info.is_a?(Hash)
      invalid_keys = info.keys.map(&:to_s) - ['whats_new']
      unless invalid_keys.empty?
        UI.user_error!("Invalid keys for #{label}[#{locale_key}]: #{invalid_keys.join(', ')}")
      end

      info[:whats_new] || info['whats_new']
    else
      info
    end

    whats_new_text = whats_new_value.to_s.strip
    if whats_new_text.empty?
      UI.user_error!("Missing whats_new for locale #{locale_key} in #{label}")
    end

    normalized[locale_key] = { whats_new: whats_new_text }
  end
end

def resolve_localized_build_info_option(options)
  localized_build_info = options[:localized_build_info]
  localized_build_info_path = options[:localized_build_info_path].to_s.strip
  whats_new = options[:whats_new]

  unless localized_build_info.nil?
    return normalize_localized_build_info(localized_build_info, label: 'localized_build_info')
  end

  unless localized_build_info_path.empty?
    file_content = read_option_file(localized_build_info_path, label: 'localized_build_info')
    parsed_content = YAML.load(file_content)
    return nil if parsed_content.nil?

    return normalize_localized_build_info(parsed_content, label: 'localized_build_info_path')
  end

  if whats_new.is_a?(Hash)
    return normalize_localized_build_info(whats_new, label: 'whats_new')
  end

  whats_new_text = resolve_text_option(
    options,
    direct_key: :whats_new,
    path_key: :whats_new_path,
    label: "What's New"
  )
  return nil if whats_new_text.nil? || whats_new_text.empty?

  whats_new_locale = options[:whats_new_locale].to_s.strip
  locale_key = whats_new_locale.empty? ? 'default' : whats_new_locale

  {
    locale_key => {
      whats_new: whats_new_text
    }
  }
end
