api.notify.registry = {}
api.notify.registry.n = 0

api.doc.notify.register = {"api.notify.register(tag, fn()) -> id", "Registers a function to be called when an Apple notification with the given tag is clicked."}
function api.notify.register(tag, fn)
  id = api.notify.registry.n + 1
  api.notify.registry[id] = {tag, fn}
  api.notify.registry.n = id
  return id
end

api.doc.notify.register = {"api.notify.unregister(id)", "Unregisters a function to no longer be called when an Apple notification with the given tag is clicked."}
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
