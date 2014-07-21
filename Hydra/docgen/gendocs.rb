# gem install github-markdown
require 'github/markdown'
require 'json'
require 'erb'
require 'pp'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

def scrape_docstring_comments
  comments = []
  Dir["../API/*"].each do |file|
    partialcomment = []
    islua = file.end_with?(".lua")
    comment = islua ? "---" : "///"
    incomment = false
    File.read(file).split("\n").each do |line|
      if line.start_with?(comment) and !line.start_with?(comment + comment) then
        incomment = true
        partialcomment << line[comment.size..-1].sub(/^\s/, '')
      elsif incomment then
        incomment = false
        comments << partialcomment
        partialcomment = []
      end
    end

    if !partialcomment.empty? then
      puts "Comment found at end of file (presumably):"
      pp partialcomment
      exit 1
    end
  end
  return comments
end

def make_module c
  {
    name: c[0].gsub('=', '').strip,
    doc: c[1..-1].join("\n").strip,
    items: [],
  }
end

def make_item c
  {
    def: c[0],
    doc: c[1..-1].join("\n").strip,
  }
end

def scrape
  comments = scrape_docstring_comments

  ismod = ->(c) { c[0].include?('===') }
  mods  = comments.select(&ismod).map{|c| make_module c}
  items = comments.reject(&ismod).map{|c| make_item c}

  orderedmods = mods.sort_by{|m| m[:name]}.reverse

  items.each do |item|
    mod = orderedmods.find{|mod| item[:def].start_with?(mod[:name])}
    if mod.nil?
      abort "error: couldn't find module for #{item[:def]}"
    end
    item[:name] = item[:def][(mod[:name].size+1)..-1].match(/\w+/)[0]
    mod[:items] << item
  end

  mods.sort_by!{|m| m[:name]}

  File.write("docs.json", JSON.pretty_generate(mods))
end

def gendocs
  dash = ARGV.include?('--dash')
  version = `defaults read "$(pwd)/../XcodeCrap/Hydra-Info" CFBundleVersion`.strip

  template = ERB.new(File.read("template.erb"))
  system("mkdir -p docs && rm -f docs/*html")

  if dash then
    puts "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);"
    puts "CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);"
  end

  groups = JSON.load(File.read("docs.json"))
  groups.each do |group|
    File.write("docs/#{group['name']}.html", template.result(binding))
    if dash then
      puts "INSERT INTO searchIndex VALUES (NULL, '#{group['name']}', 'Module', '#{group['name']}.html');"
      group['items'].each do |function|
        puts "INSERT INTO searchIndex VALUES (NULL, '#{group['name']}.#{function['name']}', 'Function', '#{group['name']}.html##{function['name']}');"
      end
    end
  end

  group = {}
  group['name'] = "Hydra #{version} API"
  group['doc'] = File.read("index.md")
  group['items'] = []

  File.write("docs/index.html", template.result(binding))
end

scrape
gendocs
