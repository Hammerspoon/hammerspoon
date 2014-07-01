doc.updates.available = {"updates.available = function(isavailable)", "Called after updates.check() runs, with a boolean parameter specifying whether an update is available. Default implementation pushes a notification when an update is available with the tag 'showupdate'."}
function updates.available(available)
  if available then
    notify.show("Hydra update available", "", "", "showupdate")
  end
end
