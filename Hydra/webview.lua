doc.api.webview.open = {"api.webview.open()", "Opens and returns a new webview instance; as with all other Hydra objects, it's just a table, and you're free to set whatever keys you want on it."}
function api.webview.open()
  local w = api.webview._open()
  return setmetatable(w, {__index = api.webview})
end

local function dirname(path)
  local f = io.popen('dirname "' .. path .. '"')
  local str = f:read()
  f:close()
  return str
end

doc.api.webview.loadfile = {"api.webview:loadfile(path)", "Loads the given file into the web view."}
function api.webview:loadfile(path)
  local f = io.open(path)
  local str = f:read('*a')
  f:close()
  self:loadstring(str, dirname(path))
end
