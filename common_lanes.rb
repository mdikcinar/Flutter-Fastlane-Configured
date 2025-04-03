# frozen_string_literal: true

# Global variables
$version_name = '1.0.0'
$build_number = 1

desc 'Add git tag and push to remote'
lane :add_git_tag_method do |options|
  ensure_git_status_clean
  
  app_name = options[:app_name]
  tag_prefix = "#{$version_name}+"
  
  begin
    add_git_tag(
      grouping: "fastlane-builds/#{app_name}",
      includes_lane: true,
      prefix: tag_prefix,
      force: true,
      build_number: $build_number
    )
    push_to_git_remote(tags: true, no_verify: true)
  rescue => e
    UI.error("Failed to add git tag: #{e.message}")
    raise
  end
end

desc 'Send notification to Slack'
lane :send_slack_message do |options|
  slack_message = options[:slack_message]
  slack_url = ENV['SLACK_HOOK_URL']

  if slack_url.nil? || slack_url.empty?
    UI.important('Skipping Slack notification - No SLACK_URL provided')
    next
  end

  begin
    slack(
      message: "#{slack_message}\nVersion: #{$version_name}+#{$build_number}",
      slack_url: slack_url,
      default_payloads: [:git_branch]
    )
  rescue => e
    UI.error("Failed to send Slack message: #{e.message}")
    # Don't raise error to continue deployment
  end
end 