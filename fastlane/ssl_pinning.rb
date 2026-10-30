# Certificate-pinning dart-defines for the release lanes of both Fastfiles
# (fastlane/Fastfile, ios/fastlane/Fastfile). The same rules as
# scripts/ci/ssl_pinning_defines.sh, which the shell build paths use; fastlane's
# `sh` runs through /bin/sh, which is not bash everywhere, so they are written
# again here rather than sourced.
#
# Pinning is on by default in staging and production, and a release built with
# pinning on and no fingerprints refuses to start (lib/main.dart). So for those
# environments a build is refused unless one of these is given, as a lane
# option or an environment variable:
#
#   ssl_fingerprints / API_SSL_FINGERPRINTS   the server's SHA-256 fingerprints
#   ssl_pinning / ENABLE_SSL_PINNING          false (or 0, no, off) to opt out
#
# The fingerprints are read as AppConfig.apiSslFingerprints reads them: split on
# commas, colons and whitespace dropped, empty entries skipped. Each remaining
# entry must be 64 hex digits, in any environment. The opt-out is trimmed, as
# the app's EnvConfig.getBool trims it. A lane option that is given wins over
# the environment variable even when it is empty, so `ssl_fingerprints:""`
# refuses rather than falling back.
require "shellwords"

module SslPinning
  OPT_OUT = %w[false 0 no off].freeze

  # The --dart-define arguments for [environment], as one shell-escaped
  # string, or an ArgumentError saying why the build is refused.
  def self.defines(environment, fingerprints:, pinning:)
    fingerprints = fingerprints.to_s
    pinning = pinning.to_s
    entries = fingerprints.split(",")
                          .map { |e| e.delete(" \t\r\n:").downcase }
                          .reject(&:empty?)
    bad = entries.find { |e| e !~ /\A[0-9a-f]{64}\z/ }
    if bad
      raise ArgumentError, "API_SSL_FINGERPRINTS entry '#{bad}' is not a " \
                           "SHA-256 fingerprint (64 hex digits, colons optional)."
    end

    defines = []
    defines << "--dart-define=API_SSL_FINGERPRINTS=#{fingerprints}" unless entries.empty?
    defines << "--dart-define=ENABLE_SSL_PINNING=#{pinning}" unless pinning.strip.empty?

    if %w[staging production].include?(environment) && entries.empty? &&
       !OPT_OUT.include?(pinning.strip.downcase)
      raise ArgumentError, "API_SSL_FINGERPRINTS is empty. Pinning is on in " \
                           "#{environment}, and a release built without " \
                           "fingerprints refuses to start. Pass " \
                           "ssl_fingerprints:<list> (or set API_SSL_FINGERPRINTS), " \
                           "or ssl_pinning:false to ship without pinning."
    end

    defines.map { |d| Shellwords.escape(d) }.join(" ")
  end

  # [defines] for a lane's [options], reading the environment variables as
  # the fallback; fails the lane with the refusal message.
  def self.lane_defines(environment, options)
    defines(
      environment,
      fingerprints: option_or_env(options, :ssl_fingerprints, "API_SSL_FINGERPRINTS"),
      pinning: option_or_env(options, :ssl_pinning, "ENABLE_SSL_PINNING")
    )
  rescue ArgumentError => e
    FastlaneCore::UI.user_error!(e.message)
  end

  # The lane option when it is given - `ssl_pinning: false` included - and
  # the environment variable otherwise.
  def self.option_or_env(options, key, variable)
    options.key?(key) ? options[key] : ENV[variable]
  end
end
