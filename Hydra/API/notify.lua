notify.registry = {}
notify.registry.n = 0

local function callback(tag)
  for k, v in pairs(notify.registry) do
    if k ~= "n" and v ~= nil then
      local fntag, fn = v[1], v[2]
      if tag == fntag then
        fn()
      end
    end
  end
end

if not _notifysetup then
  notify._setup(callback)
  _notifysetup = true
end

--- notify.register(tag, fn()) -> id
--- Registers a function to be called when an Apple notification with the given tag is clicked.
function notify.register(tag, fn)
  id = notify.registry.n + 1
  notify.registry[id] = {tag, fn}
  notify.registry.n = id
  return id
end

--- notify.unregister(id)
--- Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.
function notify.unregister(id)
  notify.registry[id] = nil
end

--- notify.unregisterall()
--- Unregisters all functions registered for notification-clicks; called automatically when user config reloads.
function notify.unregisterall()
  notify.registry = {}
  notify.registry.n = 0
end
