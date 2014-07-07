# gem install github-markdown
require 'github/markdown'
require 'json'
require 'erb'

template = ERB.new(File.read("template.erb"))
system("mkdir -p docs && rm -f docs/api*html")

groups = JSON.load(File.read("docs.json"))
groups.each do |group|
  File.write("docs/#{group['name']}.html", template.result(binding))
end

group = {}
group['name'] = "Hydra API"
group['doc'] = File.read("index.md")
group['items'] = []

File.write("docs/index.html", template.result(binding))
