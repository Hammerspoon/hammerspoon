# gem install github-markdown
require 'github/markdown'
require 'json'
require 'erb'

version = `defaults read "$(pwd)/../XcodeCrap/Hydra-Info" CFBundleVersion`.strip

template = ERB.new(File.read("template.erb"))
system("mkdir -p docs/#{version} && rm -f docs/#{version}/api*html")

groups = JSON.load(File.read("docs.json"))
groups.each do |group|
  File.write("docs/#{version}/#{group['name']}.html", template.result(binding))
end

group = {}
group['name'] = "Hydra #{version} API"
group['doc'] = File.read("index.md")
group['items'] = []

File.write("docs/#{version}/index.html", template.result(binding))
