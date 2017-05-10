local module={}

--- === hs.spoons ===
---
--- Utility and management functions for Spoons
--- Spoons are Lua plugins for Hammerspoon.
--- See http://www.hammerspoon.org/Spoons/ for more information

--- hs.spoons.repos
--- Variable
--- Table containing the list of available Spoon repositories. The key
--- of each entry is an identifier for the repository, and its value
--- is a table with the following entries:
---  * desc - Human-readable description for the repository
---  * url - Base URL for the repository. For now the repository is assumed to be hosted in GitHub, and the URL should be the main base URL of the repository. Repository metadata needs to be stored under `docs/docs.json`, and the Spoon zip files need to be stored under `Spoons/`.
---
--- Default value:
--- ```
--- {
---    default = {
---       url = "https://github.com/Hammerspoon/Spoons",
---       desc = "Main Hammerspoon Spoons repo",
---    }
--- }
--- ```
module.repos = {
   default = {
      url = "https://github.com/Hammerspoon/Spoons",
      desc = "Main Hammerspoon Spoons repo",
   }
}

module._keys = {}

local log = hs.logger.new("spoons")

-- Interpolate table values into a string
-- From http://lua-users.org/wiki/StringInterpolation
local function interp(s, tab)
   return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

-- Read a whole file into a string
local function slurp(path)
   local f = assert(io.open(path))
   local s = f:read("*a")
   f:close()
   return s
end

--- hs.spoons.newSpoon(name, basedir, metadata)
--- Method
--- Create a skeleton for a new Spoon
---
--- Parameters:
---  * name: name of the new spoon, without the `.spoon` extension
---  * basedir: (optional) directory where to create the template. Defaults to `~/.hammerspoon/Spoons`
---  * metadata: (optional) table containing metadata values to be inserted in the template. Provided values are merged with the defaults. Defaults to:
---    ```
---    {
---      version = "0.1",
---      author = "Your Name <your@email.org>",
---      homepage = "https://github.com/Hammerspoon/Spoons",
---      license = "MIT - https://opensource.org/licenses/MIT",
---      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip"
---    }
---    ```
---  * template: (optional) absolute path of the template to use for the `init.lua` file of the new Spoon. Defaults to the `templates/init.tpl` file included with Hammerspoon.
---
--- Returns:
---  * The full directory path where the template was created, or `nil` if there was an error.
function module.newSpoon(name, basedir, metadata, template)
   -- Default value for basedir
   if basedir == nil or basedir == "" then
      basedir = hs.configdir .. "/Spoons/"
   end
   -- Ensure basedir ends with a slash
   if not string.find(basedir, "/$") then
      basedir = basedir .. "/"
   end
   local meta={
      version = "0.1",
      author = "Your Name <your@email.org>",
      homepage = "https://github.com/Hammerspoon/Spoons",
      license = "MIT - https://opensource.org/licenses/MIT",
      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip",
      description = "A new Sample Spoon"
   }
   if metadata then
      for k,v in pairs(metadata) do meta[k] = v end
   end
   meta["name"]=name

   local dirname = basedir .. name .. ".spoon"
   if hs.fs.mkdir(dirname) then
      local f=assert(io.open(dirname .. "/init.lua", "w"))
      local template_file = template or module.resource_path("templates/init.tpl")
      local text=slurp(template_file)
      f:write(interp(text, meta))
      f:close()
      return dirname
   end
   return nil
end

--- hs.spoons.script_path()
--- Method
--- Return path of the current spoon.
---
--- Parameters:
---  * n - (optional) stack level for which to get the path. Defaults to 2, which will return the path of the spoon which called `script_path()`
---
--- Returns:
---  * String with the path from where the calling code was loaded.
function module.script_path(n)
   if n == nil then n = 2 end
   local str = debug.getinfo(n, "S").source:sub(2)
   return str:match("(.*/)")
end

--- hs.spoons.resource_path(partial)
--- Method
--- Return full path of an object within a spoon directory, given its partial path.
---
--- Parameters:
---  * partial - path of a file relative to the Spoon directory. For example `images/img1.png` will refer to a file within the `images` directory of the Spoon.
---
--- Returns:
---  * Absolute path of the file. Note: no existence or other checks are done on the path.
function module.resource_path(partial)
   return(module.script_path(3) .. partial)
end

--- hs.spoons.bindHotkeysToSpec(def, map)
--- Method
--- Map a number of hotkeys according to a definition table
---
--- Parameters:
---  * def - table containing name-to-function definitions for the hotkeys supported by the Spoon. Each key is a hotkey name, and its value must be a function that will be called when the hotkey is invoked.
---  * map - table containing name-to-hotkey definitions, as supported by [bindHotkeys in the Spoon API](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys). Not all the entries in `def` must be bound, but if any keys in `map` don't have a definition, an error will be produced.
---
--- Returns:
---  * None
function module.bindHotkeysToSpec(def,map)
   local spoonpath = module.script_path(3)
   for name,key in pairs(map) do
      if def[name] ~= nil then
         local keypath = spoonpath .. name
         if module._keys[keypath] then
            module._keys[keypath]:delete()
         end
         module._keys[keypath]=hs.hotkey.bindSpec(key, def[name])
      else
         log.ef("Error: Hotkey requested for undefined action '%s'", name)
      end
   end
end

--- hs.spoons.list()
--- Method
--- Return a list of installed/loaded Spoons
---
--- Parameters:
---  * only_loaded - only return loaded Spoons (skips those that are installed but not loaded). Defaults to `false`
---
--- Returns:
---  * Table with a list of installed/loaded spoons (depending on the value of `only_loaded`). Each entry is a table with the following entries:
---    * `name` - Spoon name
---    * `loaded` - boolean indication of whether the Spoon is loaded (`true`) or only installed (`false`)
---    * `version` - Spoon version number. Available only for loaded Spoons.
function module.list(only_loaded)
   local iterfn, dirobj = hs.fs.dir(hs.configdir .. "/Spoons")
   local res = {}
   repeat
      local f = dirobj:next()
      if f then
         if string.match(f, ".spoon$") then
            local s = f:gsub(".spoon$", "")
            local l = (spoon[s] ~= nil)
            if (not only_loaded) or l then
               local new = { name = s, loaded = l }
               if l then new.version = spoon[s].version end
               table.insert(res, new)
            end
         end
      end
   until f == nil
   return res
end

-- Internal function to execute a command and return its output with trailing EOLs trimmed. If the command fails, an error message is logged.
function _x(cmd, errfmt, ...)
   log.df("Executing command: %s", cmd)
   local output, status = hs.execute(cmd)
   if status then
      local trimstr = string.gsub(output, "\n*$", "")
      log.df("Success, returning output '%s'", trimstr)
      return trimstr
   else
      log.df("Command failed, output: %s", output)
      log.ef(errfmt, ...)
      return nil
   end
end

--- hs.spoons.installSpoonFromZipURL(url)
--- Method
--- Download a Spoon zip file and install it.
---
--- Parameters:
---  * url - URL of the zip file to install.
---
--- Returns:
---  * `true` if the installation was correctly initiated (not necessarily completed), `false` otherwise
function module.installSpoonFromZipURL(url)
   local urlparts = hs.http.urlParts(url)
   local dlfile = urlparts.lastPathComponent
   if dlfile and dlfile ~= "" and urlparts.pathExtension == "zip" then
      hs.http.asyncGet(url, nil, hs.fnutils.partial(_installSpoonFromZipURLgetCallback, urlparts))
      return true
   else
      log.ef("Invalid URL %s, must point to a zip file", url)
      return nil
   end
end

-- Internal callback function to finalize the installation of a spoon after the zip file has been downloaded.
function _installSpoonFromZipURLgetCallback(urlparts, status, body, headers)
   if status < 0 then
      log.ef("Error downloading %s, error: %s", urlparts.absoluteURL, body)
      return nil
   else
      -- Write the zip file to disk
      local tmpdir=_x("/usr/bin/mktemp -d", "Error creating temporary directory to download new spoon.")
      if not tmpdir then return nil end
      local outfile = string.format("%s/%s", tmpdir, urlparts.lastPathComponent)
      local f=assert(io.open(outfile, "w"))
      f:write(body)
      f:close()

      -- Check its contents - only one *.spoon directory should be in there
      output = _x(string.format("/usr/bin/unzip -l %s '*.spoon/' | /usr/bin/awk '$NF ~ /\\.spoon\\/$/ { print $NF }' | /usr/bin/wc -l", outfile),
                  "Error examining downloaded zip file %s, leaving it in place for your examination.", outfile)
      if output then
         if (tonumber(output) or 0) == 1 then
            -- Uncompress it
            if _x(string.format("/usr/bin/unzip %s -d %s 2>&1", outfile, tmpdir),
                  "Error uncompressing file %s, leaving it in place for your examination.", outfile) then
               -- And finally, install it using Hammerspoon itself
               if _x(string.format("/usr/bin/open %s/*.spoon", tmpdir), "Error installing the spoon file %s/*.spoon", tmpdir) then
                  log.f("Downloaded and installed %s", urlparts.absoluteURL)
                  _x(string.format("/bin/rm -rf '%s'", outdir), "Error removing directory %s", outdir)
                  return true
               end
            end
         else
            log.ef("The downloaded zip file %s is invalid - it should contain exactly one spoon. Leaving it in place for your examination.", outfile) 
         end
      end
   end
   return nil
end

-- Internal callback to process and store the data from docs.json about a repository
function _storeRepoJSON(repo, status, body, hdrs)
   if status < 0 then
      log.ef("Error fetching JSON data for repository '%s'. Error: %s", repo, body)
   else
      local json = hs.json.decode(body)
      if json then
         module.repos[repo].data = {}
         for i,v in ipairs(json) do
            v.download_url = module.repos[repo].download_base_url .. "/" .. v.name .. ".spoon.zip"
            module.repos[repo].data[v.name] = v
         end
         log.df("Updated JSON data for repository '%s'", repo)
      else
         log.ef("Invalid JSON received for repository '%s': %s", repo, body)
      end
   end
end

--- hs.spoons.updateRepo(repo)
--- Method
--- Fetch and store locally the information about the contents of a Spoons repository
---
--- Parameters:
---  * repo - name of the repository to update. Defaults to `"default"`.
---
--- Returns:
---  * None
function module.updateRepo(repo)
   if not repo then repo = 'default' end
   if module.repos[repo] and module.repos[repo].url then
      module.repos[repo].json_url = string.gsub(module.repos[repo].url, "/$", "") .. "/raw/master/docs/docs.json"
      module.repos[repo].download_base_url = string.gsub(module.repos[repo].url, "/$", "") .. "/raw/master/Spoons/"
      hs.http.asyncGet(module.repos[repo].json_url, nil, hs.fnutils.partial(_storeRepoJSON, repo))
   else
      log.ef("Invalid or unknown repository '%s'", repo)
   end
end

--- hs.spoons.updateAllRepos()
--- Method
--- Fetch and store locally the information about the contents of all registered Spoons repositories
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function module.updateAllRepos()
   for k,v in pairs(module.repos) do
      module.updateRepo(k)
   end
end

--- hs.spoons.installSpoonFromRepo(name, repo)
--- Method
--- Install a Spoon from a registered repository
---
--- Parameters:
---  * name = Name of the Spoon to install.
---  * repo - Name of the repository to use. Defaults to `"default"`
---
--- Returns:
---  * `true` if the installation was correctly initiated, `false` otherwise.
function module.installSpoonFromRepo(name, repo)
   if not repo then repo = 'default' end
   if module.repos[repo] then
      if module.repos[repo].data then
         if module.repos[repo].data[name] then
            return module.installSpoonFromZipURL(module.repos[repo].data[name].download_url)
         else
            log.ef("Spoon '%s' does not exist in repository '%s'. Please check and try again.", name, repo)
         end
      else
         log.ef("Repository data not available - call hs.spoons.updateRepo('%s'), then try again.", repo)
      end
   else
      log.ef("Invalid or unknown repository '%s'", repo)
   end
   return nil
end

return module
