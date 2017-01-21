--- hs.finalcutpro.MenuBar
---
--- Represents the Final Cut Pro X menu bar, providing functions that allow different tasks to be accomplished.
---
--- Author: David Peterson (david@randombits.org)
---

--- Standard Modules
local log											= require("hs.logger").new("menubar")
local json											= require("hs.json")
local axutils										= require("hs.finalcutpro.axutils")
local just											= require("hs.just")

local MenuBar = {}

MenuBar.MENU_MAP_FILE								= "hs/finalcutpro/menumap.json"
MenuBar.ROLE										= "AXMenuBar"

--- hs.finalcutpro.MenuBar:new(App) -> MenuBar
--- Function
--- Constructs a new MenuBar for the specified App.
---
--- Parameters:
---  * app - The App instance the MenuBar belongs to.
---
--- Returns:
---  * a new MenuBar instance
---
function MenuBar:new(app)
	o = {
	  _app 		= app
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function MenuBar:app()
	return self._app
end

function MenuBar:UI()
	return axutils.cache(self, "_ui", function()
		local appUI = self:app():UI()
		return appUI and axutils.childWith(appUI, "AXRole", MenuBar.ROLE)
	end)
end

function MenuBar:getMenuMap()
	if not MenuBar._menuMap then
		local file = io.open(MenuBar.MENU_MAP_FILE, "r")
		if file then
			local content = file:read("*all")
			file:close()
			MenuBar._menuMap = json.decode(content)
			log.d("Loaded menu map from '" .. MenuBar.MENU_MAP_FILE .. "'")
		else
			MenuBar._menuMap = {}
		end
	end
	return MenuBar._menuMap
end

--- hs.finalcutpro.MenuBar:selectMenu(...) -> boolean
--- Function
--- Selects a Final Cut Pro Menu Item based on the list of menu titles in English.
---
--- Parameters:
---  * ... - The list of menu items you'd like to activate, for example: 
---            select("View", "Browser", "as List")
---
--- Returns:
---  * `true` if the press was successful.
---
function MenuBar:selectMenu(...)
	local menuItemUI = self:findMenuUI(...)
	
	if menuItemUI then
		return menuItemUI:doPress()
	end
	return false
end

function MenuBar:isChecked(...)
	local menuItemUI = self:findMenuUI(...)
	return menuItemUI and self:_isMenuChecked(menuItemUI)
end

function MenuBar:isEnabled(...)
	local menuItemUI = self:findMenuUI(...)
	return menuItemUI and menuItemUI:attributeValue("AXEnabled")
end

function MenuBar:_isMenuChecked(menu)
	return menu:attributeValue("AXMenuItemMarkChar") ~= nil
end

function MenuBar:checkMenu(...)
	local menuItemUI = self:findMenuUI(...)
	if menuItemUI and not self:_isMenuChecked(menuItemUI) then
		if menuItemUI:doPress() then
			return just.doUntil(function() return self:_isMenuChecked(menuItemUI) end)
		end
	end
	return false
end

function MenuBar:uncheckMenu(...)
	local menuItemUI = self:findMenuUI(...)
	if menuItemUI and self:_isMenuChecked(menuItemUI) then
		if menuItemUI:doPress() then
			return just.doWhile(function() return self:_isMenuChecked(menuItemUI) end)
		end
	end
	return false
end

--- Finds a specific Menu UI element for the provided path. 
--- Eg `findMenuUI("Edit", "Copy")` returns the 'Copy' menu item in the 'Edit' menu.
function MenuBar:findMenuUI(...)
	-- Start at the top of the menu bar list
	local menuMap = self:getMenuMap()
	local menuUI = self:UI()
	
	if not menuUI then
		return nil
	end
	
	local menuItemUI = nil
	
	for i=1,select('#', ...) do
		step = select(i, ...)
		if type(step) == "number" then
			menuItemUI = menuUI[step]
		elseif type(step) == "function" then
			for i,child in ipairs(menuUI) do
				if step(child) then
					menuItemUI = child
					break
				end
			end
		elseif menuMap and menuMap[step] then
			-- We have the menu name in our list
			local item = menuMap[step]
			menuItemUI = menuUI[item.id]
			menuMap = item.items
		else
			-- We don't have it in our list, so look it up manually. Hopefully they are in English!
			log.w("Searching manually for '"..step.."'.")
			menuItemUI = axutils.childWith(menuUI, "AXTitle", step)
		end
		
		if menuItemUI then
			if #menuItemUI == 1 then
				-- Assign the contained AXMenu to the menuUI - it contains the next set of AXMenuItems
				menuUI = menuItemUI[1]
				assert(not menuUI or menuUI:role() == "AXMenu")
			end
		else
			log.w("Unable to find a menu called '"..step.."'.")
			return nil
		end
	end
	return menuItemUI
end

--- Returns the set of menu items in the provided path. If the path contains a menu, the
--- actual children of that menu are returned, otherwise the menu item itself is returned.
function MenuBar:findMenuItemsUI(...)
	local menu = self:findMenuUI(...)
	if menu and #menu == 1 then
		return menu[1]:children()
	end
	return menu
end

--- hs.finalcutpro.MenuBar:generateMenuMap() -> boolean
--- Function
--- Generates a map of the menu bar and saves it in the location specified
--- in MenuBar.MENU_MAP_FILE.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * True is successful otherwise Nil
---
function MenuBar:generateMenuMap()
	local menuMap = self:_processMenuItems(self:UI())
	
	-- Opens a file in append mode
	file = io.open(MenuBar.MENU_MAP_FILE, "w")

	if file then
		file:write(json.encode(menuMap))
		file:close()
		return true
	end

	return nil
end

function MenuBar:_processMenuItems(menu)
	local count = #menu
	if count then
		local items = {}
		for i,child in ipairs(menu) do
			local title = child:attributeValue("AXTitle")
			-- log.d("Title: "..inspect(title))
			if title and title ~= "" then
				local item = {id = i}
				local submenu = child[1]
				if submenu and submenu:role() == "AXMenu" then
					local children = self:_processMenuItems(submenu)
					if children then
						item.items = children
					end
				end
				items[title] = item
			end
		end
		return items
	else
		return nil
	end
end

return MenuBar