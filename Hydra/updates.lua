doc.updates.available = {"updates.available = function(isavailable)", "Called after updates.check() runs, with a boolean parameter specifying whether an update is available. Default implementation pushes a notification when an update is available with the tag 'showupdate'."}
function updates.available(available)
  if available then
    notify.show("Hydra update available", "", "", "showupdate")
  end
end

doc.updates.check = {"updates.check()", "Checks for an update. If one is available, calls updates.available(true); otherwise calls updates.available(false)."}
function updates.check()
  updates.getversions(function(versions)
      local hasupdate = false
      local thisversion = updates.currentversion()

      for _, version in pairs(versions) do
        if version > thisversion then hasupdate = true end
      end

      if hasupdate then
        updates.available()
      end
  end)
end
