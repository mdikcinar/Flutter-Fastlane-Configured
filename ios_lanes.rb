# frozen_string_literal: true

platform :ios do
  desc 'Setup App Store Connect API Key'
  lane :connect_app_store do |options|
    validate_app_store_credentials

    key_id = ENV['APP_STORE_CONNECT_KEY_IDENTIFIER']
    issuer_id = ENV['APP_STORE_CONNECT_ISSUER_ID']
    key_content = ENV['APP_STORE_CONNECT_PRIVATE_KEY']

    UI.message("App Store Connect Credentials:")
    UI.message("Key ID: #{key_id}")
    UI.message("Issuer ID: #{issuer_id}")

    app_store_connect_api_key(
      key_id: key_id,
      issuer_id: issuer_id,
      key_filepath: key_filepath,
      key_content: key_content,
      duration: 1200,
      in_house: false
    )
  end

  desc 'Read and increment version numbers'
  lane :read_and_increment_build_number do |options|
    $version_name = get_flutter_version()
    UI.message("Version from pubspec: #{$version_name}")
    
    increment_version_number(version_number: $version_name)

    previous_build_number = latest_testflight_build_number(
      version: $version_name,
      initial_build_number: 0
    )

    $build_number = previous_build_number + 1
    UI.message("Previous TestFlight build number: #{previous_build_number}")
    UI.message("New build number: #{$build_number}")
    
    increment_build_number(build_number: $build_number)
  end

  desc 'Build iOS application'
  lane :build_app_lane do |options|
    validate_ios_build_options(options)
    
    appname = options[:app_name]
    scheme = options[:scheme]

    UI.message("Building iOS app:")
    UI.message("App Name: #{appname}")
    UI.message("Scheme: #{scheme}")

    cocoapods(clean: true, use_bundle_exec: false)
  
    build_app(
      workspace: 'Runner.xcworkspace',
      scheme: scheme,
      output_directory: './../build/ios',
      output_name: "#{appname}.ipa"
    )
  end

  desc 'Upload to TestFlight'
  lane :upload_to_testflight_lane do |options|
    appname = options[:app_name]
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      ipa: "./../build/ios/#{appname}.ipa"
    )
  end

  desc 'Upload dSYM to Crashlytics'
  lane :upload_symbols_to_crashlytics_lane do |options|
    appname = options[:app_name]
    scheme = options[:scheme]

    upload_symbols_to_crashlytics(
      dsym_path: "./../build/ios/#{appname}.app.dSYM.zip",
      gsp_path: "./flavors/#{scheme}/GoogleService-Info.plist"
    )
  end

  desc 'Deploy to TestFlight'
  lane :deploy_ios do |options|
    connect_app_store(options)
    read_and_increment_build_number
    build_app_lane(options)
    upload_to_testflight_lane(options)
    upload_symbols_to_crashlytics_lane(options)
    send_slack_message(options)
    add_git_tag_method(options)
  end
end 