#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'openssl'
require 'base64'

# ensure private key is given
if ARGV.length < 1
  puts "Usage: release.sh <priv_key_file>"
  exit 1
end
pkey = File.read(ARGV[0])

# build app
puts "Rebuilding app"
system "xcodebuild clean build > /dev/null"

# get details
version = `defaults read "$(pwd)/Mjolnir/Mjolnir-Info" CFBundleVersion`.strip
zipfile = "Mjolnir-#{version}.zip"
tgzfile = "Mjolnir-#{version}.tgz"

puts "Creating #{zipfile} and #{tgzfile}"
# build .zip
FileUtils.rm_f(zipfile)
FileUtils.rm_f(tgzfile)
FileUtils.cd("build/Release/") do
  system "zip -qr  '../../#{zipfile}' Mjolnir.app"
  system "tar -czf '../../#{tgzfile}' Mjolnir.app"
end

puts "Signing #{tgzfile}"
# sign tgz
data = OpenSSL::Digest::SHA1.new.digest(File.read(zipfile))
digest = OpenSSL::Digest::DSS1.new
pkey = OpenSSL::PKey::DSA.new(pkey)
signature = Base64.encode64(pkey.sign(digest, data)).tr("\n", '')
puts "Signature: #{signature}"
