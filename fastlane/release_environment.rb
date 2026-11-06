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

  # The lanes used to fall back to https://api.example.com (or api-staging),
  # so a store lane run without base_url: or BASE_URL_<ENV> uploaded a build
  # pointing at a placeholder host, and nothing at startup refused it.
  #
  # [value] trimmed, or an ArgumentError when it is unset or on example.com.
  # [source] names where it should come from, for the message.
  def self.base_url(value, source)
    url = value.to_s.strip
    if url.empty?
      raise ArgumentError, "No API base URL: pass base_url:<url> or set #{source}."
    end
    host = url[%r{\A[a-z][a-z0-9+.-]*://(?:[^@/]*@)?([^/:?#]+)}i, 1]
    if host.nil?
      raise ArgumentError, "base_url #{url} is not an absolute URL " \
                           "(https://host/...)."
    end
    # A trailing dot names the same host (api.example.com.).
    host = host.downcase.chomp('.')
    if host == 'example.com' || host.end_with?('.example.com')
      raise ArgumentError, "base_url #{url} is the starter's placeholder " \
                           "host. Pass base_url:<url> or set #{source} to " \
                           "your API."
    end
    url
  end

  # [base_url], failing the lane with the message.
  def self.lane_base_url(value, source)
    base_url(value, source)
  rescue ArgumentError => e
    FastlaneCore::UI.user_error!(e.message)
  end
end
