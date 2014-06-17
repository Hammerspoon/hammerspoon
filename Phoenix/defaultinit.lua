local defaultinit = {}

function defaultinit.open_sample_config()
  local phoenix = require("phoenix")
  os.execute("open " .. phoenix.resourcesdir .. "/sample_config.lua")
end

function defaultinit.run()
  local phoenix = require("phoenix")
  local menu = require("menu")
  menu.show(function()
      return {
        {title = "Open Sample Config", fn = defaultinit.open_sample_config},
        {title = "Reload Config", fn = phoenix.reload},
        {title = "-"},
        {title = "About", fn = phoenix.show_about_panel},
        {title = "Quit Phoenix", fn = phoenix.quit},
      }
  end)

  local alert = require("alert")
  alert.show("Welcome to Phoenix 2.0! Click the menu icon to find a sample config :)", 5)
end

return defaultinit
