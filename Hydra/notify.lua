api.notify.registry = {}
api.notify.registry.n = 0

doc.api.notify.register = {"api.notify.register(tag, fn()) -> id", "Registers a function to be called when an Apple notification with the given tag is clicked."}
function api.notify.register(tag, fn)
  id = api.notify.registry.n + 1
  api.notify.registry[id] = {tag, fn}
  api.notify.registry.n = id
  return id
end

doc.api.notify.unregister = {"api.notify.unregister(id)", "Unregisters a function to no longer be called when an Apple notification with the given tag is clicked."}
function api.notify.unregister(id)
  api.notify.registry[id] = nil
end

function api.notify._clicked(tag)
  for k, v in pairs(api.notify.registry) do
    if k ~= "n" and v ~= nil then
      local fntag, fn = v[1], v[2]
      if tag == fntag then
        fn()
      end
    end
  end
end

doc.api.notify.unregisterall = {"api.notify.unregisterall()", "Unregisters all functions registered for notification-clicks; called automatically when user config reloads."}
function api.notify.unregisterall()
  api.notify.registry = {}
  api.notify.registry.n = 0
end
