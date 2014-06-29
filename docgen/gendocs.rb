require 'json'
require 'erb'

template = ERB.new(File.read("template.erb"))
system("mkdir -p docs && rm -f docs/api*html")

groups = JSON.load(File.read("hydra.json"))
groups.each do |group|
  # group: name, doc, items
  # item: name, doc, def
  File.write("docs/#{group['name']}.html", template.result(binding))
end
