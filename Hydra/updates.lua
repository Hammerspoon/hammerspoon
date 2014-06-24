api.doc.updates.available = {"api.updates.available = function(newversion, currentversion, changelog)", "Called when an update is avaiable, determined by api.updates.check(). Default implementation pushes a notification about it with the tag 'showupdate'."}
function api.updates.available(newversion, currentversion, changelog)
  api.updates.newversion = newversion
  api.updates.currentversion = currentversion
  api.updates.changelog = changelog
  api.notify.show("Hydra update available", "", "Click here to see the changelog and maybe even install it", "showupdate")
end

api.doc.updates.notyet = {"api.updates.notyet = function()", "Called when no update is avaiable, determined by api.updates.check(); default implementation does nothing."}
function api.updates.notyet()
  -- api.alert("No update available.")
end
