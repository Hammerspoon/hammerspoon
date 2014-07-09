#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'io/console'

print "github password: "
pass = STDIN.noecho(&:gets).chomp

# build app
system "xcodebuild clean build"

# get details
humanversion = `defaults read "$(pwd)/Hydra/XcodeCrap/Hydra-Info" CFBundleShortVersionString`.strip
version = `defaults read "$(pwd)/Hydra/XcodeCrap/Hydra-Info" CFBundleVersion`.strip
filename = "Hydra-#{version}.zip"

# build .zip
FileUtils.rm_f(filename)
FileUtils.cd("build/Release/") do
  system "zip -r '../../#{filename}' Hydra.app"
end
puts "Created #{filename}"

# template
template = <<END
#### Additions

#### Changes

#### Deletions

#### Thanks!

You rock.
END

# create release
create_release_json = {
  tag_name: version,
  name: "Hydra #{humanversion}",
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
