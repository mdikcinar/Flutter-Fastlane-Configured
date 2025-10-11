# frozen_string_literal: true

platform :android do
  desc 'Read version from pubspec.yaml'
  lane :read_version do |options|
    $version_name = get_flutter_version()
    UI.message("Version: #{$version_name}")
  end

  desc 'Increment build number for Play Store'
  lane :increment_build_number_lane do |options|
    app_identifier = options[:app_identifier]
    json_key_data = ENV['GOOGLE_SERVICE_ACCOUNT_CREDENTIALS']

    UI.message("App Identifier: #{app_identifier}")

    UI.user_error!("Missing app_identifier") unless app_identifier
    UI.user_error!("Missing JSON key data") unless json_key_data

    begin
      previous_build_number = google_play_track_version_codes(
        package_name: app_identifier,
        track: 'internal',
        json_key: json_key_data
      )[0]

      $build_number = previous_build_number + 1
      UI.message("Previous build number: #{previous_build_number}")
      UI.message("New build number: #{$build_number}")
      
      increment_version_code(
        gradle_file_path: './app/build.gradle',
        version_code: $build_number
      )
    rescue => e
      UI.error("Failed to increment build number: #{e.message}")
      raise
    end
  end

  desc 'Increment build number for Firebase distribution'
  lane :increment_firebase_build_number_lane do |options|
    firebase_app_id = options[:firebase_app_id]
    UI.user_error!("Missing firebase_app_id") unless firebase_app_id

    begin
      latest_release = firebase_app_distribution_get_latest_release(
        app: firebase_app_id
      )

      $build_number = latest_release ? latest_release[:buildVersion].to_i + 1 : 1
      
      increment_version_code(
        gradle_file_path: './app/build.gradle',
        version_code: $build_number
      )
    rescue => e
      UI.error("Failed to increment Firebase build number: #{e.message}")
      raise
    end
  end

  desc 'Build Flutter application'
  lane :flutter_build do |options|
    validate_build_options(options)
    
    flavor = options[:flavor]
    target = options[:target]
    build_type = options[:build] || 'appbundle'

    UI.message("Building with:")
    UI.message("Flavor: #{flavor}")
    UI.message("Target: #{target}")
    UI.message("Build Type: #{build_type}")

    Dir.chdir '../../' do
      sh("flutter build #{build_type} --flavor #{flavor} --release -t #{target} --no-tree-shake-icons")
    end
  end

  desc 'Upload to Play Store'
  lane :build_store do |options|
    json_key_data = ENV['GOOGLE_SERVICE_ACCOUNT_CREDENTIALS']
    app_identifier = options[:app_identifier]
    flavor = options[:flavor]
    track = options[:track] || 'internal'
    
    bundle_path = "../build/app/outputs/bundle/#{flavor}Release/app-#{flavor}-release.aab"

    upload_to_play_store(
      track: track,
      aab: bundle_path,
      package_name: app_identifier,
      json_key: json_key_data
    )
  end

  desc 'Upload to Firebase App Distribution'
  lane :upload_to_firebase do |options|
    firebase_app_id = options[:firebase_app_id]
    flavor = options[:flavor]
    apk_path = "../build/app/outputs/apk/#{flavor}/release/app-#{flavor}-release.apk"

    firebase_app_distribution(
      app: firebase_app_id,
      groups: 'Internal',
      android_artifact_type: 'APK',
      android_artifact_path: apk_path
    )
  end

  desc 'Deploy to Play Store'
  lane :deploy_android do |options|
    read_version(options)
    increment_build_number_lane(options)
    flutter_build(options)
    build_store(options)

    if option_enabled?(options[:enable_slack_notification])
      send_slack_message(options)
    end

    if option_enabled?(options[:enable_git_tagging])
      add_git_tag_method(options)
    end
  end

  desc 'Deploy to Firebase'
  lane :deploy_android_firebase do |options|
    read_version(options)
    increment_firebase_build_number_lane(options)
    flutter_build(options)
    upload_to_firebase(options)

    if option_enabled?(options[:enable_slack_notification])
      send_slack_message(options)
    end

    if option_enabled?(options[:enable_git_tagging])
      add_git_tag_method(options)
    end
  end
end 
