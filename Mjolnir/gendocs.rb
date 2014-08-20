# requires: gem install github-markdown
require 'json'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

def generate_json(infiles)
  require 'pp'
  comments = []
  infiles.each do |file|
    partialcomment = []
    islua = file.end_with?(".lua")
    comment = islua ? "-" : "/"
    incomment = false
    File.read(file).split("\n").each do |line|
      if line.start_with?(comment*3) and !line.start_with?(comment*4) then
        incomment = true
        partialcomment << line[3..-1].sub(/^\s/, '')
      elsif incomment then
        incomment = false
        comments << partialcomment
        partialcomment = []
      end
    end
    unless partialcomment.empty?
      abort "Comment found at end of file (presumably):\n #{partialcomment.pretty_inspect}"
    end
  end

  newmod  = ->(c) {{name: c[0].gsub('=', '').strip, doc: c[1..-1].join("\n").strip, items: []}}
  newitem = ->(c) {{type: "Function", name: nil, def: c[0], doc: c[1..-1].join("\n").strip}}
  # TODO: figure out what the type really is (it's not always a function); probably requires a stricter docs format

  ismod = ->(c) { c[0].include?('===') }
  mods  = comments.select(&ismod).map(&newmod)
  items = comments.reject(&ismod).map(&newitem)
  orderedmods = mods.sort_by{|m|m[:name]}.reverse

  items.each do |item|
    mod = orderedmods.find{|mod| item[:def].start_with?(mod[:name])}
    if mod.nil?
      abort "error: couldn't find module for #{item[:def]}"
    end
    item[:name] = item[:def][(mod[:name].size+1)..-1].match(/\w+/)[0]
    mod[:items] << item
  end

  mods.sort_by!{|m|m[:name]}
  puts mods.to_json
end

def generate_sql_in(infile)
  mods = JSON.parse(File.read(infile))
  mods.each do |mod|
    puts  "INSERT INTO searchIndex VALUES (NULL, '#{mod['name']}', 'Module', '#{mod['name']}.html');"
    mod['items'].each do |item|
      puts  "INSERT INTO searchIndex VALUES (NULL, '#{mod['name']}.#{item['name']}', '#{mod['type']}', '#{mod['name']}.html##{item['name']}');"
    end
  end
end

def generate_sql_out(infile)
  mods = JSON.parse(File.read(infile))
  mods.each do |mod|
    puts "DELETE FROM searchIndex WHERE name='#{mod['name']}' AND type='Module' AND path='#{mod['name']}.html';"
    mod['items'].each do |item|
      puts "DELETE FROM searchIndex WHERE name='#{mod['name']}.#{item['name']}' AND type='Function' AND path='#{mod['name']}.html##{item['name']}';"
    end
  end
end

def generate_html(infile, dir)
  require 'github/markdown'
  require 'erb'
  template = ERB.new(DATA.read)
  mods = JSON.parse(File.read(infile))
  mods.each do |mod|
    File.write("#{dir}/#{mod['name']}.html", template.result(binding))
  end
end

case ARGV.shift
when "--json"   then generate_json     ARGV
when "--sqlin"  then generate_sql_in  *ARGV
when "--sqlout" then generate_sql_out *ARGV
when "--html"   then generate_html    *ARGV
end

__END__
<html>
  <head>
    <title>Penknife docs: <%= mod['name'] %> module</title>
    <style type="text/css">
      a { text-decoration: none; }
      a:hover { text-decoration: underline; }
      header { padding-bottom: 50px; }
      section { border-top: 1px solid #777; padding-bottom: 20px; }
    </style>
  </head>
  <body>
    <header>
      <h1><%= mod['name'] %></h1>
      <%= GitHub::Markdown.render_gfm(mod['doc']) %>
    </header>
    <% mod['items'].sort_by{|m|m['def']}.each do |item| %>
    <section id="<%= item['name'] %>">
      <a name="//apple_ref/cpp/<%= item['type'] %>/<%= item['name'] %>" class="dashAnchor"></a>
      <h3><a href="#<%= item['name'] %>"><%= item['name'] %></a></h3>
      <code><%= item['def'] %></code>
      <%= GitHub::Markdown.render_gfm(item['doc']) %>
    </section>
    <% end %>
  </body>
</html>
