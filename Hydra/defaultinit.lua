local defaultinit = {}

function defaultinit.open_sample_config()
  os.execute("open " .. hydra.resourcesdir .. "/sample_config.lua")
end

function defaultinit.run()
  hydra.menu.show(function()
      return {
        {title = "Open Sample Config", fn = defaultinit.open_sample_config},
        {title = "Reload Config", fn = hydra.reload},
        {title = "-"},
        {title = "About", fn = hydra.showabout},
        {title = "Quit Hydra", fn = os.exit},
      }
  end)

  hydra.alert("Welcome to Hydra 2.0! Click the menu icon to find a sample config :)", 5)
end

return defaultinit
