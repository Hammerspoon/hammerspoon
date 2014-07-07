#!/usr/bin/env ruby

comments = []

Dir["../API/*"].each do |file|
  partialcomment = []
  lua = file.end_with?(".lua")
  incomment = false
  File.read(file).split("\n").each do |line|
    comment = lua ? "---" : "///"
    if line.start_with?(comment) then
      incomment = true
      partialcomment << line[comment.size..-1].sub(/^\s/, '')
    elsif incomment then
      incomment = false
      comments << partialcomment
      partialcomment = []
    end
  end
end

docs = []
keys = []

comments.each do |c|
  header = c.shift
  ismodule = !(header =~ /[.:]/)

  if ismodule
    c.shift # whitespace
    module_name = header
    module_body = c.join("\n")
    docs << {
      name: module_name,
      doc: module_body,
      items: []
    }
  else
    m = header.match /(\w+)[\.:](\w+)/
    module_name = m[1]
    key_name = m[2]
    key_header = header
    key_body = c.join("\n")
    keys << [module_name, key_name, key_header, key_body]
  end
end

keys.each do |mod, key, head, body|
  doc = docs.find{|doc| doc[:name] == mod}
  doc[:items] << {
    def: head,
    name: key,
    doc: body,
  }
end

require 'json'
File.write("docs.json", JSON.dump(docs))
