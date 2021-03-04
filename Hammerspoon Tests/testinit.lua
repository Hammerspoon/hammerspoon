-- Note, this file is loaded by lsunit.lua

-- Function to test that all extensions load correctly
function testrequires()
  failed = {}
  for k,v in pairs(hs._extensions) do
    print(string.format("checking extension '%s'", k))
    res, ext = pcall(load(string.format("return hs.%s", k)))
    if res then
      if type(ext) ~= 'table' then
        failreason = string.format("type of 'hs.%s' is '%s', was expecting 'table'", k, type(ext))
        print(failreason)
        table.insert(failed, failreason)
      end
    else
      failreason = string.format("failed to load 'hs.%s', error was '%s'", k, ext)
      print(failreason)
      table.insert(failed, failreason)
    end
  end
  return table.concat(failed, "💩")
end

print("-- Hammerspoon Tests testinit.lua loaded")
