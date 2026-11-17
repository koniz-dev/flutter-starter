# The IPA `flutter build ipa` exported, for ios/fastlane/Fastfile.
#
# The lanes assumed build/ios/ipa/Runner.ipa, but Xcode names the exported
# file after the app's product name, which follows the bundle name (the
# package name here, renamed by the setup brick), not the Runner target.
# So the lanes clear the export directory before building and then take the
# one .ipa found there, whatever it is called.
require 'fileutils'

module IosIpa
  # Relative to the repository root.
  EXPORT_DIR = 'build/ios/ipa'.freeze

  # Removes earlier exports, so the next lookup cannot pick a stale IPA.
  def self.clear(repo_root)
    FileUtils.rm_rf(File.expand_path(EXPORT_DIR, repo_root))
  end

  # The absolute path of the single .ipa under [EXPORT_DIR], or an
  # ArgumentError naming what was found instead.
  def self.find(repo_root)
    dir = File.expand_path(EXPORT_DIR, repo_root)
    ipas = Dir.glob(File.join(dir, '*.ipa')).sort
    return ipas.first if ipas.length == 1

    if ipas.empty?
      raise ArgumentError, "No IPA found in #{dir}. Check the " \
                           '`flutter build ipa` output above for export errors.'
    end
    raise ArgumentError, "Expected one IPA in #{dir}, found #{ipas.length}: " \
                         "#{ipas.map { |p| File.basename(p) }.join(', ')}. " \
                         'Delete the stale ones and run the lane again.'
  end

  # [find], failing the lane with the message.
  def self.lane_path(repo_root)
    find(repo_root)
  rescue ArgumentError => e
    FastlaneCore::UI.user_error!(e.message)
  end
end
