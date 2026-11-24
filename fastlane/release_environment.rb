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
  # The rules, and messages, are those of the shell builds
  # (scripts/ci/release_base_url.sh).
  #
  # [value] trimmed, or an ArgumentError when it is unset, not https, spelled
  # with whitespace, "%" or a backslash, or on example.com.
  # [source] names where it should come from, for the message.
  # [environment] names the release, for the message.
  def self.base_url(value, source,
                    environment = source.sub(/\ABASE_URL_/, '').downcase)
    url = value.to_s.strip
    if url.empty?
      raise ArgumentError, "No API base URL: pass base_url:<url> or set #{source}."
    end
    # Dart reads %61 as "a" and a backslash as "/", so either could spell the
    # placeholder host past the check below; whitespace is never part of a URL.
    if url.match?(/[%\\[:space:]]/)
      raise ArgumentError, "base URL '#{url}' contains whitespace, '%' or a " \
                           'backslash. Write the host and path literally.'
    end
    # A staging or production release refuses any other scheme at startup
    # (lib/main.dart).
    unless url.match?(%r{\Ahttps://.}i)
      raise ArgumentError, "base URL '#{url}' is not an absolute https URL. " \
                           "A #{environment} release refuses any other " \
                           'scheme at startup.'
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

  # Explicit lane option wins; otherwise use the resolved environment's URL.
  def self.for_environment(environment, value = nil)
    environment = normalize(environment)
    source = "BASE_URL_#{environment.upcase}"
    base_url(value || ENV[source], source, environment)
  end

  # [for_environment], failing the lane with the message.
  def self.lane_base_url(value, environment)
    for_environment(environment, value)
  rescue ArgumentError => e
    FastlaneCore::UI.user_error!(e.message)
  end
end
