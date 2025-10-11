# Fastlane Configuration

This directory contains Fastlane configuration files for automating iOS and Android deployment processes.

## File Structure

```
fastlane/
├── Fastfile              # Main Fastlane configuration file that imports all lanes
├── .env.example          # Example environment variables file
├── helpers.rb            # Helper methods used across lanes
├── common_lanes.rb       # Common lanes used by both platforms
├── android_lanes.rb      # Android specific lanes
└── ios_lanes.rb          # iOS specific lanes
```

## Files Description

### Fastfile

Main configuration file that imports all other lane files. This file serves as an entry point for all Fastlane commands.

### .env files

Fastlane automatically loads dotenv files that live alongside your Fastfile (for example `.env`, `.env.default`, or `.env.production`). Copy `.env.example` to `.env`, fill in your credentials, and keep the real file out of version control. In CI, export the same variables or provide lane-specific dotenv files as needed.

### .env.example

Template listing the environment variables required by the shared lanes. Use it as a reference when creating your own `.env` files.

### helpers.rb

Contains helper methods used across different lanes:

- `get_flutter_version`: Reads version from pubspec.yaml
- `validate_build_options`: Validates Android/iOS build options
- `validate_ios_build_options`: Validates iOS specific build options
- `validate_app_store_credentials`: Validates App Store credentials

### common_lanes.rb

Contains lanes used by both platforms:

- `add_git_tag_method`: Adds git tag for releases
- `send_slack_message`: Sends deployment notifications to Slack

Both of these lanes are optional and disabled by default. Enable them per deployment by passing `enable_slack_notification: true` and/or `enable_git_tagging: true` when calling a deploy lane. Slack notifications also require a `slack_message` option and the `SLACK_HOOK_URL` environment variable.

### android_lanes.rb

Android specific lanes:

- `read_version`: Reads version from pubspec.yaml
- `increment_build_number_lane`: Increments Play Store build number
- `increment_firebase_build_number_lane`: Increments Firebase build number
- `flutter_build`: Builds Android app
- `build_store`: Uploads to Play Store
- `upload_to_firebase`: Uploads to Firebase App Distribution
- `deploy_android`: Main deployment lane for Play Store
- `deploy_android_firebase`: Main deployment lane for Firebase

### ios_lanes.rb

iOS specific lanes:

- `connect_app_store`: Sets up App Store Connect API
- `read_and_increment_build_number`: Updates version and build numbers
- `build_app_lane`: Builds iOS app
- `upload_to_testflight_lane`: Uploads to TestFlight
- `upload_symbols_to_crashlytics_lane`: Uploads dSYM to Crashlytics
- `deploy_ios`: Main deployment lane for TestFlight

## Usage

### Prerequisites
- Ruby with Fastlane installed (`gem install fastlane`) or available via Bundler
- Flutter SDK on the PATH for Android builds
- Xcode and CocoaPods for iOS builds
- Access to the credentials described below

### Common Configuration
- Copy `.env.example` to `.env` (or a lane-specific variant such as `.env.prod`) inside every `fastlane/` folder that runs these lanes, and populate it with your secrets
- In CI, export the same variables or supply dedicated dotenv files via Fastlane's `--env` flag
- Keep secrets out of version control (`.env` is already ignored in this repository)
- Override values per app inside each platform-specific Appfile only when a lane requires something different from the shared defaults

#### Environment Variables
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect API key identifier (e.g. `ABC123XYZ`)
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID GUID
- `APP_STORE_CONNECT_PRIVATE_KEY` **or** `APP_STORE_CONNECT_PRIVATE_KEY_PATH`: provide the key contents directly or a path (relative or absolute) to the `.p8` file
- `GOOGLE_SERVICE_ACCOUNT_CREDENTIALS`: path to the Google Play service account JSON file or the raw JSON contents
- `SLACK_HOOK_URL`: Optional Slack Incoming Webhook URL used by `send_slack_message`
- `FIREBASE_TOKEN`: Optional token for Firebase App Distribution CLI when using `deploy_android_firebase`

### Lane Inputs
**iOS `deploy_ios`**
- `app_name` (required): used for artifact filenames and git tags
- `scheme` (required): Xcode scheme to build
- `export_options` (required): path to an export options plist or a hash accepted by `build_app`
- Optional: `slack_message` plus `enable_slack_notification: true` and/or `enable_git_tagging: true`

**Android `deploy_android`**
- `app_identifier` (required): package name used when uploading to Google Play
- `flavor` and `target` (required): forwarded to `flutter build`
- `track` (optional, default `internal`): Google Play track
- `app_name` (optional but required if git tagging is enabled): used for artifact naming
- Optional: `slack_message` plus `enable_slack_notification: true` and/or `enable_git_tagging: true`

**Android `deploy_android_firebase`**
- `firebase_app_id` (required): Firebase App Distribution app identifier
- `flavor` and `target` (required): forwarded to `flutter build`
- `build` (optional, default `apk`): Flutter build type (e.g. `appbundle` or `apk`)
- `app_name` (optional but required if git tagging is enabled): used for artifact naming
- Optional: `slack_message` plus `enable_slack_notification: true` and/or `enable_git_tagging: true`

### Running Lanes Locally
- Ensure a populated `.env` (or lane-specific variant) exists in the `fastlane/` directory before running commands
- Execute Fastlane commands from the `fastlane/` directory so the relative paths in the lanes resolve correctly
- iOS example: `bundle exec fastlane ios deploy_ios app_name:"Example APP" scheme:"production" export_options:"./fastlane/export_options.plist"`
- Android (Play Store) example: `bundle exec fastlane android deploy_android app_name:"Example APP" app_identifier:"com.example.exampleapp" flavor:"production" target:"lib/main_production.dart"`
- Android (Firebase) example: `bundle exec fastlane android deploy_android_firebase app_name:"Example APP Dev" firebase_app_id:"1:123" flavor:"development" target:"lib/main_development.dart"`

### Project-Specific Configuration

Each app in the monorepo can have its own Fastfile and Appfile in their respective directories:

```
apps/
└── your_app/
    ├── android/
    │   └── fastlane/
    │       ├── Fastfile    # Android specific configuration
    │       └── Appfile     # Android credentials and app identifiers
    └── ios/
        └── fastlane/
            ├── Fastfile    # iOS specific configuration
            └── Appfile     # iOS credentials and app identifiers
```

#### Example iOS Fastfile

```ruby
# apps/better_iptv/ios/fastlane/Fastfile

default_platform(:ios)

# Clone the shared Fastfile containing the deploy lane logic
require 'tmpdir'
Dir.mktmpdir do |tmpdir|
  clone_folder = File.join(tmpdir, "fastlane-config")
  sh("git clone git@github.com:mdikcinar/Fastlane-Configured.git #{clone_folder}")
  # Import all required files from the cloned repository
  import "#{clone_folder}/Fastfile"
end

# .env files that live next to this Fastfile (e.g. .env, .env.prod) are loaded automatically by Fastlane

platform :ios do
  desc "Deploy production application to TestFlight"
  lane :prod do
    deploy_ios(
      scheme: "production",
      app_name: "Example APP",
      slack_message: "Example APP iOS: Production app successfully released!",
      export_options: {
        provisioningProfiles: {
          "com.example.bundleid" => "Provisioning Profile Name",
          "com.example.bundleid2" => "Provisioning Profile Name 2"
        }
      },
      enable_slack_notification: true, # optional, default false
      enable_git_tagging: true,        # optional, default false
    )
  end
end
```

#### Example iOS Appfile

```ruby
# apps/example_app/ios/fastlane/Appfile

# Credentials are typically loaded from .env; override here only if you need per-app values

# You can use environment variables or provide static values
for_platform :ios do
  for_lane :prod do
    app_identifier 'com.example.exampleapp'
  end
  for_lane :dev do
    app_identifier 'com.example.exampleapp.dev'
  end
end

```

#### Example Android Fastfile

```ruby
# apps/better_iptv/android/fastlane/Fastfile

default_platform(:android)

# Clone the shared Fastfile containing the deploy lane logic
require 'tmpdir'
Dir.mktmpdir do |tmpdir|
  clone_folder = File.join(tmpdir, "fastlane-config")
  sh("git clone git@github.com:mdikcinar/Fastlane-Configured.git #{clone_folder}")
  # Import all required files from the cloned repository
  import "#{clone_folder}/Fastfile"
end

# .env files that live next to this Fastfile (e.g. .env, .env.prod) are loaded automatically by Fastlane

platform :android do
  desc "Deploy production application to Play Store"
  lane :prod do
    deploy_android(
      track: "internal",
      app_name: "Example APP",
      app_identifier: "com.example.exampleapp",
      flavor: "production",
      target: "lib/main_production.dart",
      slack_message: "Example APP Android: Production app successfully released!",
      enable_slack_notification: true, # optional, default false
      enable_git_tagging: true,        # optional, default false
    )
  end

  desc "Deploy development build to Firebase"
  lane :dev do
    deploy_android_firebase(
      firebase_app_id: "1:1234567890:android:abcdef",
      app_identifier: "com.example.exampleapp.dev",
      app_name: "Example APP Dev",
      flavor: "development",
      target: "lib/main_development.dart",
      build: "apk",
      slack_message: "Example APP Android: Development build uploaded to Firebase!",
      enable_slack_notification: true, # optional, default false
      enable_git_tagging: true,        # optional, default false
    )
  end
end
```

#### Example Android Appfile

```ruby
# apps/better_iptv/android/fastlane/Appfile

# Credentials are typically loaded from .env; override here only if you need per-app values
```

### Configuration Priority

1. Environment variables exported by the shell or CI pipeline override everything else
2. Lane-specific dotenv files (e.g. `.env.prod`, `.env.deploy_ios`) override values from the base `.env`
3. The base `.env` file supplies default values for all lanes
4. Values hard-coded inside an Appfile override defaults for the matching platform/lane when present
