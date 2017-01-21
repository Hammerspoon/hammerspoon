-- Imports
local settings							= require("hs.settings")
local eventtap							= require("hs.eventtap")
local fcp								= require("hs.finalcutpro")
local timer								= require("hs.timer")

local log								= require("hs.logger").new("fsshrtct")

local kc								= require("hs.fcpxhacks.modules.shortcuts.keycodes")
local tools								= require("hs.fcpxhacks.modules.tools")

-- Constants

local PRIORITY = 10000

--------------------------------------------------------------------------------
-- Supported Full Screen Keys:
--------------------------------------------------------------------------------
local FULLSCREEN_KEYS = { "Unfavorite", "Favorite", "SetSelectionStart", "SetSelectionEnd", "AnchorWithSelectedMedia", "AnchorWithSelectedMediaAudioBacktimed", "InsertMedia", "AppendWithSelectedMedia" }


-- The module
local mod = {}

function mod.isEnabled()
	return settings.get("fcpxHacks.enableShortcutsDuringFullscreenPlayback") or false
end

function mod.setEnabled(enabled)
	settings.set("fcpxHacks.enableShortcutsDuringFullscreenPlayback", enabled)
	mod.update()
end

--------------------------------------------------------------------------------
-- TOGGLE ENABLE SHORTCUTS DURING FULLSCREEN PLAYBACK:
--------------------------------------------------------------------------------
function mod.toggleEnabled()
	local enabled = mod.isEnabled()
	mod.setEnabled(not enabled)
end

--------------------------------------------------------------------------------
-- TOGGLE ENABLE SHORTCUTS DURING FULLSCREEN PLAYBACK:
--------------------------------------------------------------------------------
function mod.update()
	if mod.isEnabled() and fcp:fullScreenWindow():isShowing() then
		log.df("Watching for fullscreen shortcuts")
		mod.keyUpWatcher:start()
		mod.keyDownWatcher:start()
	else
		log.df("Not watching for fullscreen shortcuts")
		mod.keyUpWatcher:stop()
		mod.keyDownWatcher:stop()
	end
end

--------------------------------------------------------------------------------
-- ENABLE SHORTCUTS DURING FCPX FULLSCREEN PLAYBACK:
--------------------------------------------------------------------------------

local function ninjaKeyStroke(whichModifier, whichKey)
	--------------------------------------------------------------------------------
	-- Press 'Escape':
	--------------------------------------------------------------------------------
	eventtap.keyStroke({""}, "escape")

	--------------------------------------------------------------------------------
	-- Perform Keystroke:
	--------------------------------------------------------------------------------
	eventtap.keyStroke(whichModifier, whichKey)

	--------------------------------------------------------------------------------
	-- Go back to Full Screen Playback:
	--------------------------------------------------------------------------------
	fcp:performShortcut("PlayFullscreen")
end

local function performCommand(cmd, whichModifier, whichKey)
	local chars = cmd['characterString']
	if chars and chars ~= "" and whichKey == kc.keyCodeTranslator(chars)
		and tools.modifierMatch(whichModifier, cmd['modifiers']) then
			log.df("performing command: %s", hs.inspect(cmd))

		-- perform the keystroke
		ninjaKeyStroke(whichModifier, whichKey)
		return true
	end
	return false
end

local function checkCommand(whichModifier, whichKey)
	--------------------------------------------------------------------------------
	-- Don't repeat if key is held down:
	--------------------------------------------------------------------------------
	if mod.watcherWorking then
		debugMessage("plugins.fullscreen.shortcuts.checkCommand() already in progress.")
		return false
	end
	mod.watcherWorking = true

	--------------------------------------------------------------------------------
	-- Only Continue if in Full Screen Playback Mode:
	--------------------------------------------------------------------------------
	if fcp:fullScreenWindow():isShowing() then

		--------------------------------------------------------------------------------
		-- Get Active Command Set:
		--------------------------------------------------------------------------------
		local activeCommandSet = fcp:getActiveCommandSet()
		if type(activeCommandSet) ~= "table" then
			debugMessage("Failed to get Active Command Set. Error occurred in plugins.fullscreen.shortcuts.checkCommand().")
			return
		end

		--------------------------------------------------------------------------------
		-- Key Detection:
		--------------------------------------------------------------------------------
		for _, whichShortcutKey in pairs(FULLSCREEN_KEYS) do
			local selectedCommandSet = activeCommandSet[whichShortcutKey]

			if selectedCommandSet then
				if selectedCommandSet[1] and type(selectedCommandSet[1]) == "table" then
					--------------------------------------------------------------------------------
					-- There are multiple shortcut possibilities for this command:
					--------------------------------------------------------------------------------
					for _,cmd in ipairs(selectedCommandSet) do
						if performCommand(cmd, whichModifier, whichKey) then
							-- All done
							return
						end
					end
				else
					--------------------------------------------------------------------------------
					-- There is only a single shortcut possibility for this command:
					--------------------------------------------------------------------------------
					if performCommand(selectedCommandSet, whichModifier, whichKey) then
						-- All done
						return
					end
				end
			end
		end

	end
end

local function cancelCommand()
	mod.watcherWorking = false
end

local function init()
	cancelCommand()

	mod.keyUpWatcher = eventtap.new({ eventtap.event.types.keyUp }, function(event)
		timer.doAfter(0.0000001, function() cancelCommand() end)
	end)
	mod.keyDownWatcher = eventtap.new({ eventtap.event.types.keyDown }, function(event)
		timer.doAfter(0.0000001, function() checkCommand(event:getFlags(), event:getKeyCode()) end)
	end)
end


-- The Plugin
local plugin = {}

plugin.dependencies = {
	["hs.fcpxhacks.plugins.menu.automation.options"] = "options",
}

function plugin.init(deps)
	-- Initialise the module
	init()

	-- Watch for the full screen window
	fcp:fullScreenWindow():watch({
		show	= mod.update,
		hide	= mod.update,
	})

	-- Add the menu item
	deps.options:addItem(PRIORITY, function()
		return { title = i18n("enableShortcutsDuringFullscreen"),	fn = mod.toggleEnabled,		checked = mod.isEnabled() }
	end)

	return mod
end

return plugin