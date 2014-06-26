local fallbackinit = {}

function fallbackinit.open_sample_config()
  os.execute("open " .. api.resourcesdir .. "/sample_config.lua")
end

function fallbackinit.run()
  api.menu.show(function()
      return {
        {title = "Open Sample Config", fn = fallbackinit.open_sample_config},
        {title = "Reload Config", fn = api.reload},
        {title = "-"},
        {title = "About", fn = api.showabout},
        {title = "Quit Hydra", fn = os.exit},
      }
  end)

  api.alert("Welcome to Hydra 1.0! Click the menu icon to find a sample config :)", 10)
end

return fallbackinit
