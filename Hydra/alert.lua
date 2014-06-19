local alert = {}

function alert.show(str, duration)
  __api.alert_show(str, duration or 2.0)
end

return alert
