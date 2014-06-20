function hydra.require(path)
  local userfile = os.getenv("HOME") .. "/.hydra/" .. path .. ".lua"
  local exists, isdir = hydra.fileexists(userfile)
  if exists and not isdir then
    dofile(userfile)
  else
    hydra.alert("Cannot find file: " .. path)
  end
end

function hydra.reload()
  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = hydra.fileexists(userfile)

  if exists and not isdir then
    local ok, err = pcall(function()
        dofile(userfile)
    end)
    if not ok then
      hydra.alert(err, 5)
    end
  else
    local defaultinit = dofile(hydra.resourcesdir .. "/defaultinit.lua")
    defaultinit.run()
  end
end

local t = getmetatable(hydra.alert) or {}
t.__call = function(self, msg, dur)
  hydra.alert.show(msg, dur)
end
setmetatable(hydra.alert, t)
