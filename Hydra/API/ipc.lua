--- ipc
---
--- Interface with Hydra from the command line.

--- ipc.handler(str) -> value
--- The default handler for IPC, called by hydra-cli. Default implementation evals the string and returns the result.
--- You may override this function if for some reason you want to implement special evaluation rules for executing remote commands.
--- The return value of this function is always turned into a string via tostring() and returned to hydra-cli.
--- If an error occurs, the error message is returned instead.
function ipc.handler()
end

local function rawhandler(str)
  local fn, err = load(str)
  if fn then return fn() else return err end
end

ipc.handler = rawhandler

function ipc._handler(raw, str)
  local fn = ipc.handler
  if raw then fn = rawhandler end
  local ok, val = hydra.call(function() return fn(str) end)
  return val
end

--- ipc.link(prefix = "/usr/local")
--- Symlinks ${prefix}/bin/hydra and ${prefix}/share/man/man1/hydra.1
function ipc.link(prefix)
  -- TODO: anything
end
