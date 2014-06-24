doc.api.updates.available = {"api.updates.available = function(update)", "Called when an update is avaiable, determined by api.updates.check(); update is a table with fields: newversion, currentversion, changelog; Default implementation pushes a notification about it with the tag 'showupdate'."}
function api.updates.available()
  api.notify.show("Hydra update available", "", "Click here to see the changelog and maybe even install it", "update")
end
