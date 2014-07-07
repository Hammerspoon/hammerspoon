local function normalizeversion(str)
  local fn = str:gmatch("(b?)(%d+)")
  local _, major = fn()
  local _, minor = fn()
  local bug = 0
  local beta = 0
  for a, b in fn do
    if a == 'b' then beta = b else bug = b end
  end
  return string.format("%02d-%02d-%02d-%02d", major, minor, bug, beta)
end

--- updates.available = function(isavailable)
--- Called after updates.check() runs, with a boolean parameter specifying whether an update is available. Default implementation pushes a notification when an update is available with the tag 'showupdate'.
function updates.available(available)
  if available then
    notify.show("Hydra update available", "", "", "showupdate")
  end
end

--- updates.check()
--- Checks for an update. If one is available, calls updates.available(true); otherwise calls updates.available(false).
function updates.check()
  updates.getversions(function(versions)
      local hasupdate = false
      local thisversion = normalizeversion(updates.currentversion())

      for _, version in pairs(versions) do
        if normalizeversion(version) > thisversion then hasupdate = true end
      end

      updates.available(hasupdate)
  end)
end
