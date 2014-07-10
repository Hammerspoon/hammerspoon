local function normalize(str)
  return str:gsub("(%d+)", function(n) return ("%02d"):format(n) end)
end

--- updates.check(fn(isavailable))
--- Checks for an update. Calls the given function with a boolean representing whether a new update is available.
function updates.check(fn)
  updates.getversions(function(versions)
      table.sort(versions, function(a, b) return normalize(a.number) < normalize(b.number) end)
      local hasupdate = normalize(versions[#versions].number) > normalize(updates.currentversion())
      fn(hasupdate)
  end)
end

--- updates.changelogurl
--- String of the URL that contains the changelog, rendered via Markdown
updates.changelogurl = "https://github.com/sdegutis/hydra/releases"
