-- hs.alert.show('testing init.lua loaded')
for k,v in pairs(_extensions) do
  print(string.format("checking extension '%s'", k))
  res, ext = pcall(load(string.format("return hs.%s", k)))
  if res then
    if type(ext) ~= 'table' then
      print(string.format("type of 'hs.%s' is '%s', was expecting 'table'", k, type(ext)))
    end
  else
    print(string.format("failed to load 'hs.%s', error was '%s'", k, ext))
  end
end