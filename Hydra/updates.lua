doc.api.updates.available = {"api.updates.available = function(isavailable)", "Called after api.updates.check() runs, with a boolean parameter specifying whether an update is available. Default implementation pushes a notification when an update is available with the tag 'showupdate'."}
function api.updates.available(available)
  if available then
    api.notify.show("Hydra update available", "", "Click here to see the changelog and maybe even install it", "showupdate")
  end
end
