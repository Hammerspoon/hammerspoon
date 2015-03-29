--- === hs.itunes ===
---
--- Controls for iTunes music player

local itunes = {}

local alert = require "hs.alert"
local as = require "hs.applescript"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "iTunes" to ' .. cmd
  local ok, result = as.applescript(_cmd)
  if ok then
    return result
  else
    return nil
  end
end

--- hs.itunes.play()
--- Function
--- Toggles play/pause of current iTunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.play()
  tell('playpause')
end

--- hs.itunes.pause()
--- Function
--- Pauses of current iTunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.pause()
  tell('pause')
end

--- hs.itunes.next()
--- Function
--- Skips to the next itunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.next()
  tell('next track')
end

--- hs.itunes.previous()
--- Function
--- Skips to previous itunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.previous()
  tell('previous track')
end

--- hs.itunes.displayCurrentTrack()
--- Function
--- Displays information for current track on screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.displayCurrentTrack()
  local artist = tell('artist of the current track as string') or "Unknown artist"
  local album  = tell('album of the current track as string') or "Unknown album"
  local track  = tell('name of the current track as string') or "Unknown track"
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

--- hs.itunes.getCurrentArtist()
--- Function
--- Gets the name of the current Artist
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Artist of the current track
function itunes.getCurrentArtist()
    return tell('artist of the current track as string')
end

--- hs.itunes.getCurrentAlbum()
--- Function
--- Gets the name of the current Album
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Album of the current track
function itunes.getCurrentAlbum()
    return tell('album of the current track as string')
end

--- hs.itunes.getCurrentTrack()
--- Function
--- Gets the name of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the current track
function itunes.getCurrentTrack()
    return tell('name of the current track as string')
end

return itunes
