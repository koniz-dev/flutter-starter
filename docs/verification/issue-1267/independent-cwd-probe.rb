
require 'json'
$lanes = {}
$uploads = []
def default_platform(*) end
def platform(*) yield end
def desc(*) end
def lane(name, &body) $lanes[name] = body end
def build_bundle(**options) 'fixture.aab' end
def upload_to_play_store(**options) $uploads << options end
module UI
  def self.success(*) end
end

root = File.expand_path(ARGV.fetch(0))
fastdir = File.join(root, 'fastlane')
Dir.chdir(fastdir) do
  eval(File.read('Fastfile'), binding, 'Fastfile')
  $lanes.each do |name, body|
    next unless name.to_s.start_with?('upload')
    body.call(base_url: 'https://api.release.test', ssl_pinning: 'false')
  end
end
expected = File.join(fastdir, 'metadata/android')
raise 'wrong lane count' unless $uploads.size == 5
$uploads.each do |call|
  unknown = call.keys - %i[aab track package_name skip_upload_apk skip_upload_aab skip_upload_metadata skip_upload_images skip_upload_screenshots release_status metadata_path json_key json_key_data skip_upload_changelogs]
  raise "unknown supply keys: #{unknown}" unless unknown.empty?
end
raise 'wrong metadata root' unless $uploads.last[:metadata_path] == expected
Dir.chdir(root) { raise 'action cannot read metadata' unless File.file?(File.join($uploads.last[:metadata_path], 'en-US/changelogs/default.txt')) }
puts "PASS relative-filename eval, fastlane lane cwd then action cwd: #{expected}"
puts JSON.pretty_generate($uploads)
