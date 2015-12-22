--- === hs.fs ===
---
--- Access/inspect the filesystem
---
--- Home: http://keplerproject.github.io/luafilesystem/
---
--- This module is produced by the Kepler Project under the name "Lua File System"

local module = require("hs.fs.internal")
module.volume = require("hs.fs.volume")

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
---   * NSURLVolumeIsEjectableKey - Boolean indicating if the volume can be ejected
---   * NSURLVolumeIsInternalKey - Boolean indicating if the volume is an internal drive or an external drive
---   * NSURLVolumeIsLocalKey - Boolean indicating if the volume is a local or remote drive
---   * NSURLVolumeIsReadOnlyKey - Boolean indicating if the volume is read only
---   * NSURLVolumeIsRemovableKey - Boolean indicating if the volume is removable
---   * NSURLVolumeMaximumFileSizeKey - Maximum file size the volume can support, in bytes
---   * NSURLVolumeUUIDStringKey - The UUID of volume's filesystem
---   * NSURLVolumeURLForRemountingKey - For remote volumes, the network URL of the volume
---   * NSURLVolumeLocalizedNameKey - Localized version of the volume's name
---   * NSURLVolumeNameKey - The volume's name
---   * NSURLVolumeLocalizedFormatDescriptionKey - Localized description of the volume
--- * Not all keys will be present for all volumes
local host = require("hs.host")
module.volume.allVolumes = host.volumeInformation

return module
