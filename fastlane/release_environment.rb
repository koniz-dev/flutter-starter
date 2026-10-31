# The ENVIRONMENT a release lane may build, for both Fastfiles
# (fastlane/Fastfile, ios/fastlane/Fastfile).
#
# A release configured as development refuses to start (lib/main.dart), so a
# lane given environment:development built an app that would not open.
# build_all.sh and build.yml already refuse it; the lanes do too. The value
# is trimmed and lowercased first, as AppConfig.environment reads it.
module ReleaseEnvironment
  ALLOWED = %w[staging production].freeze

  # [value] normalised, or an ArgumentError naming the allowed values.
  def self.normalize(value)
    environment = value.to_s.strip.downcase
    return environment if ALLOWED.include?(environment)

    raise ArgumentError, "environment:#{value} is not a release environment. " \
                         "Use #{ALLOWED.join(' or ')}: a release built as " \
                         "anything else refuses to start."
  end

  # [normalize], failing the lane with the message.
  def self.lane_value(value)
    normalize(value)
  rescue ArgumentError => e
    FastlaneCore::UI.user_error!(e.message)
  end
end
