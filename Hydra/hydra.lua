local hydra = {}

function hydra.show_about_panel()
  __api.hydra_show_about_panel()
end

function hydra.quit()
  __api.hydra_quit()
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f~=nil then
    io.close(f)
    return true
  else
    return false
  end
end

local alert = require("alert")

function hydra.reload()
  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local initfile_exists = file_exists(userfile)

  if initfile_exists then
    local ok, err = pcall(function()
        dofile(userfile)
    end)
    if not ok then
      alert.show(err, 5)
    end
  else
    local defaultinit = require("defaultinit")
    defaultinit.run()
  end
end

return hydra
