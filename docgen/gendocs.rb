require 'json'
require 'erb'

@template = ERB.new(File.read("template.erb"))

def gengroup(_prefixes, group)
  group['prefixes'] = _prefixes.dup << group['name']
  group['namespace'] = group['prefixes'].join('.')

  combined_prefixes = []
  group['prefix_pairs'] = []
  group['prefixes'].each do |prefix|
    combined_prefixes << prefix
    group['prefix_pairs'] << [prefix, combined_prefixes.dup]
  end

  group['subgroups'].each { |g| gengroup group['prefixes'], g }
  File.write("docs/#{group['namespace']}.html", @template.result(binding))
end

`rm -f docs/api*html`
gengroup [], JSON.load(File.read("hydra.json"))
