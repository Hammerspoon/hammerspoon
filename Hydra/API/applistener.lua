--- applistener.stopall()
--- Stops app applisteners; automatically called when user config reloads.
function applistener.stopall()
  local function isapplistener(o) return type(o) == "userdata" end
  fnutils.each(fnutils.filter(applistener._registry, isapplistener), applistener.stop)
end
