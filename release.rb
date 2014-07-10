#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'io/console'

# ensure private key is given
if ARGV.length < 1
  puts "Usage: release.sh <priv_key_file>"
  exit 1
end
privkeyfile = ARGV[0]

# get password
print "github password: "
pass = STDIN.noecho(&:gets).chomp

# build app
system "xcodebuild clean build"

# get details
version = `defaults read "$(pwd)/Hydra/XcodeCrap/Hydra-Info" CFBundleVersion`.strip
filename = "Hydra-#{version}.zip"

# build .zip
FileUtils.rm_f(filename)
FileUtils.cd("build/Release/") do
  system "zip -r '../../#{filename}' Hydra.app"
end
puts "Created #{filename}"

# sign zip
signature = `openssl dgst -sha1 -binary < #{filename} | openssl dgst -dss1 -sign #{privkeyfile} | openssl enc -base64`

# template
template = <<END
#### Changes

#### Download Verification

Signature: #{signature}
END


# create release
create_release_json = {
  tag_name: version,
  name: "Hydra #{version}",
  body: template,
  draft: true,
  prerelease: false
}.to_json
create_url = "https://api.github.com/repos/sdegutis/hydra/releases"
release = JSON.load(`curl -u sdegutis:#{pass} -X POST --data '#{create_release_json}' '#{create_url}'`)

# upload zip
upload_url = "https://uploads.github.com/repos/sdegutis/hydra/releases/#{release['id']}/assets?name=#{filename}"
system "curl -u sdegutis:#{pass} -H 'Content-Type: application/zip' --data-binary @#{filename} '#{upload_url}'"

# open in browser for me
system "open #{release['html_url']}"
