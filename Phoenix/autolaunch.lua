local autolaunch = {}

function autolaunch.get() return __api.autolaunch_get() end
function autolaunch.enable()  __api.autolaunch_set(true) end
function autolaunch.disable() __api.autolaunch_set(false) end

return autolaunch
