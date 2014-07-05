doc.webview.open = {"webview.open()", "Opens and returns a new webview instance; as with all other Hydra objects, it's just a table, and you're free to set whatever keys you want on it."}
function webview.open()
  local w = webview._open()
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
