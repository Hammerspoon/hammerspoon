doc.webview.create = {"webview.create()", "Creates and returns a new (hidden) webview instance."}
function webview.create()
  local w = webview._create()
  return setmetatable(w, {__index = webview})
end

local function dirname(path)
  local f = io.popen('dirname "' .. path .. '"')
  local str = f:read()
  f:close()
  return str
end

doc.webview.loadfile = {"webview:loadfile(path)", "Loads the given file in the web view."}
function webview:loadfile(path)
  local f = io.open(path)
  local str = f:read('*a')
  f:close()
  self:loadstring(str, dirname(path))
end

doc.webview.window = {"webview:window() -> window", "Return the window that represents the given webview."}
function webview:window()
  return fnutils.find(window.allwindows(), function(win) return win:id() == self:id() end)
end
