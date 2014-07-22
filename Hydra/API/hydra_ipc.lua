local fakestdout = ""
local function ipcprint(...)
  local things = table.pack(...)
  for i = 1, things.n do
    if i > 1 then fakestdout = fakestdout .. "\t" end
    fakestdout = fakestdout .. tostring(things[i])
  end
  fakestdout = fakestdout .. "\n"
end

--- === hydra.ipc ===
---
--- Interface with Hydra from the command line.

local function rawhandler(str)
  local fn, err = load("return " .. str)
  if not fn then fn, err = load(str) end
  if fn then return fn() else return err end
end

--- hydra.ipc.handler(str) -> value
--- The default handler for IPC, called by hydra-cli. Default implementation evals the string and returns the result.
--- You may override this function if for some reason you want to implement special evaluation rules for executing remote commands.
--- The return value of this function is always turned into a string via tostring() and returned to hydra-cli.
--- If an error occurs, the error message is returned instead.
hydra.ipc.handler = rawhandler

function hydra.ipc._handler(raw, str)
  local originalprint = print
  fakestdout = ""
  print = function(...) originalprint(...) ipcprint(...) end

  local fn = hydra.ipc.handler
  if raw then fn = rawhandler end
  local results = table.pack(pcall(function() return fn(str) end))

  local str = fakestdout .. tostring(results[2])
  for i = 3, results.n do
    str = str .. "\t" .. tostring(results[i])
  end

  print = originalprint
  return str
end
