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
  local fn = hydra.ipc.handler
  if raw then fn = rawhandler end
  local results = table.pack(pcall(function() return fn(str) end))

  local str = tostring(results[2])
  for i = 3, results.n do
    str = str .. "\t" .. tostring(results[i])
  end
  return str
end
