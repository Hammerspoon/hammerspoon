--- === hs.fs ===
---
--- Access/inspect the filesystem
---
--- This module is partial superset of LuaFileSystem 1.8.0 (http://keplerproject.github.io/luafilesystem/). It has been modified to remove functions which do not apply to macOS filesystems and additional functions providing macOS specific filesystem information have been added.

local module = require("hs.libfs")
module.volume = require("hs.libfsvolume")
module.xattr  = require("hs.libfsxattr")

--- hs.fs.xattr.getHumanReadable(path, attribute, [options], [position]) -> string | true | nil
--- Function
--- A wrapper to [hs.fs.xattr.get](#get) which returns non UTF-8 data as a hexadecimal dump provided by `hs.utf8.hexDump`.
---
--- Parameters:
---  * `path`      - A string specifying the path to the file or directory to get the extended attribute from
---  * `attribute` - A string specifying the name of the extended attribute to get the value of
---  * `options`   - An optional table containing options as described in this module's documentation header. Defaults to {} (an empty array).
---  * `position`  - An optional integer specifying the offset within the extended attribute. Defaults to 0. Setting this argument to a value other than 0 is only valid when `att  ribute` is "com.apple.ResourceFork".
---
--- Returns:
---  * if the returned data does not conform to proper UTF-8 byte sequences, passes the string through `hs.utf8.hexDump` first.  Otherwise the return values follow the description for [hs.fs.xattr.get](#get) .
---
--- Notes:
---  * This is provided for testing and debugging purposes; in general you probably want [hs.fs.xattr.get](#get) once you know how to properly understand the data returned for the attribute.
---  * This is similar to the long format option in the command line `xattr` command.
module.xattr.getHumanReadable = function(...)
    local val = module.xattr.get(...)
    if type(val) == "string" and val ~= hs.cleanUTF8forConsole(val) then
        val = require("hs.utf8").hexDump(val)
    end
    return val
end

--- hs.fs.volume.allVolumes([showHidden]) -> table
--- Function
--- Returns a table of information about disk volumes attached to the system
---
--- Parameters:
---  * showHidden - An optional boolean, true to show hidden volumes, false to not show hidden volumes. Defaults to false.
---
--- Returns:
---  * A table of information, where the keys are the paths of disk volumes
---
--- Notes:
---  * This is an alias for `hs.host.volumeInformation()`
---  * The possible keys in the table are:
---   * NSURLVolumeTotalCapacityKey - Size of the volume in bytes
---   * NSURLVolumeAvailableCapacityKey - Available space on the volume in bytes
---   * NSURLVolumeIsAutomountedKey - Boolean indicating if the volume was automounted
---   * NSURLVolumeIsBrowsableKey - Boolean indicating if the volume can be browsed
---   * NSURLVolumeIsEjectableKey - Boolean indicating if the volume should be ejected before its media is removed
---   * NSURLVolumeIsInternalKey - Boolean indicating if the volume is an internal drive or an external drive
---   * NSURLVolumeIsLocalKey - Boolean indicating if the volume is a local or remote drive
---   * NSURLVolumeIsReadOnlyKey - Boolean indicating if the volume is read only
---   * NSURLVolumeIsRemovableKey - Boolean indicating if the volume's media can be physically ejected from the drive (e.g. a DVD)
---   * NSURLVolumeMaximumFileSizeKey - Maximum file size the volume can support, in bytes
---   * NSURLVolumeUUIDStringKey - The UUID of volume's filesystem
---   * NSURLVolumeURLForRemountingKey - For remote volumes, the network URL of the volume
---   * NSURLVolumeLocalizedNameKey - Localized version of the volume's name
---   * NSURLVolumeNameKey - The volume's name
---   * NSURLVolumeLocalizedFormatDescriptionKey - Localized description of the volume
--- * Not all keys will be present for all volumes
--- * The meanings of NSURLVolumeIsEjectableKey and NSURLVolumeIsRemovableKey are not generally useful for determining if a drive is removable in the modern sense (e.g. a USB drive) as much of this terminology dates back to when USB didn't exist and removable drives were things like Floppy/DVD drives. If you're trying to determine if a drive is not fixed into the computer, you may need to use a combination of these keys, but which exact combination you should use, is not consistent across macOS versions.
local host = require("hs.host")
module.volume.allVolumes = host.volumeInformation

--- hs.fs.getFinderComments(path) -> string
--- Function
--- Get the Finder comments for the file or directory at the specified path
---
--- Parameters:
---  * path - the path to the file or directory you wish to get the comments of
---
--- Returns:
---  * a string containing the Finder comments for the file or directory specified.  If no comments have been set for the file, returns an empty string.  If an error occurs, most commonly an invalid path, this function will throw a Lua error.
---
--- Notes:
---  * This function uses `hs.osascript` to access the file comments through AppleScript
module.getFinderComments = function(path)
    local script = [[
tell application "Finder"
  set filePath to "]] .. tostring(path) .. [[" as posix file
  get comment of (filePath as alias)
end tell
]]
    local state, result, raw = require("hs.osascript").applescript(script)
    if state then
        return result
    else
        error(raw.NSLocalizedDescription, 2)
    end
end

--- hs.fs.setFinderComments(path, comment) -> boolean
--- Function
--- Set the Finder comments for the file or directory at the specified path to the comment specified
---
--- Parameters:
---  * path    - the path to the file or directory you wish to set the comments of
---  * comment - a string specifying the comment to set.  If this parameter is missing or is an explicit nil, the existing comment is cleared.
---
--- Returns:
---  * true on success; on error, most commonly an invalid path, this function will throw a Lua error.
---
--- Notes:
---  * This function uses `hs.osascript` to access the file comments through AppleScript
module.setFinderComments = function(path, comment)
    if comment == nil then comment = "" end
    local script = [[
tell application "Finder"
  set filePath to "]] .. tostring(path) .. [[" as posix file
  set comment of (filePath as alias) to "]] .. comment .. [["
end tell
]]
    local state, _, raw = require("hs.osascript").applescript(script)
    if state then
        return state
    else
        error(raw.NSLocalizedDescription, 2)
    end
end

-- easier to wrap here than adjust in internal.m since we have a more macOS way to resolve
-- symlinks
local hs_fs_symlinkAttributes = module.symlinkAttributes
--- hs.fs.symlinkAttributes (filepath [, aname]) -> table or string or nil,error
--- Function
--- Gets the attributes of a symbolic link
---
--- Parameters:
---  * filepath - A string containing the path of a link to inspect
---  * aName - An optional attribute name. If this value is specified, only the attribute requested, is returned
---
--- Returns:
---  * A table or string if the values could be found, otherwise nil and an error string.
---
--- Notes:
---  * The return values for this function are identical to those provided by `hs.fs.attributes()` with the following addition: the attribute name "target" is added and specifies a string containing the absolute path that the symlink points to.
module.symlinkAttributes = function(...)
    local args = table.pack(...)
    if args[2] == "target" then
        return module.pathToAbsolute(args[1])
    else
        local ans = table.pack(hs_fs_symlinkAttributes(...))
        if ans.n == 1 and type(ans[1]) == "table" then
            ans[1].target = module.pathToAbsolute(args[1])
        end
        return table.unpack(ans)
    end
end

return module
