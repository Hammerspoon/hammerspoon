local phoenix = {}

function phoenix.show_about_panel()
  __api.phoenix_show_about_panel()
end

function phoenix.quit()
  __api.phoenix_quit()
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

function phoenix.reload()
  local userfile = os.getenv("HOME") .. "/.phoenix/init.lua"
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

return phoenix
