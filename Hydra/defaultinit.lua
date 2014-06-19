local defaultinit = {}

function defaultinit.open_sample_config()
  local hydra = require("hydra")
  os.execute("open " .. hydra.resourcesdir .. "/sample_config.lua")
end

function defaultinit.run()
  local hydra = require("hydra")
  local menu = require("menu")
  menu.show(function()
      return {
        {title = "Open Sample Config", fn = defaultinit.open_sample_config},
        {title = "Reload Config", fn = hydra.reload},
        {title = "-"},
        {title = "About", fn = hydra.show_about_panel},
        {title = "Quit Hydra", fn = hydra.quit},
      }
  end)

  local alert = require("alert")
  alert.show("Welcome to Hydra 2.0! Click the menu icon to find a sample config :)", 5)
end

return defaultinit
