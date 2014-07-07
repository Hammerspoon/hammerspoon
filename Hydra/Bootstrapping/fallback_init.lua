local fallbackinit = {}

function fallbackinit.open_sample_config()
  os.execute("open \"" .. hydra.resourcesdir .. "/sample_config.lua\"")
end

function fallbackinit.run()
  menu.show(function()
      return {
        {title = "Open Sample Config", fn = fallbackinit.open_sample_config},
        {title = "Reload Config", fn = hydra.reload},
        {title = "-"},
        {title = "About", fn = hydra.showabout},
        {title = "Quit Hydra", fn = os.exit},
      }
  end)

  hydra.alert("Welcome to Hydra 1.0! Click the menu icon to find a sample config :)", 10)
end

return fallbackinit
