
--- === hs.webview.toolbar ===
---
--- Create and manipulate toolbars which can be attached to the Hammerspoon console or hs.webview objects.
---
--- Toolbars are attached to titled windows and provide buttons which can be used to perform various actions within the application. Hammerspoon can use this module to add toolbars to the console or `hs.webview` objects which have a title bar (see `hs.webview.windowMasks` and `hs.webview:windowStyle`). Toolbars are identified by a unique identifier which is used by OS X to identify information which can be auto saved in the application's user defaults to reflect changes the user has made to the toolbar button order or active button list (this requires setting [hs.webview.toolbar:autosaves](#autosaves) and [hs.webview.toolbar:canCustomize](#canCustomize) both to true).
---
--- Multiple copies of the same toolbar can be made with the [hs.webview.toolbar:copy](#copy) method so that multiple webview windows use the same toolbar, for example. If the user customizes a copied toolbar, changes to the active buttons or their order will be reflected in all copies of the toolbar.
---
--- Example:
--- ~~~lua
--- t = require("hs.webview.toolbar")
--- a = t.new("myConsole", {
---         { id = "select1", selectable = true, image = hs.image.imageFromName("NSStatusAvailable") },
---         { id = "NSToolbarSpaceItem" },
---         { id = "select2", selectable = true, image = hs.image.imageFromName("NSStatusUnavailable") },
---         { id = "notShown", default = false, image = hs.image.imageFromName("NSBonjour") },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "navGroup", label = "Navigation", groupMembers = { "navLeft", "navRight" }},
---         { id = "navLeft", image = hs.image.imageFromName("NSGoLeftTemplate"), allowedAlone = false },
---         { id = "navRight", image = hs.image.imageFromName("NSGoRightTemplate"), allowedAlone = false },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "cust", label = "customize", fn = function(t, w, i) t:customizePanel() end, image = hs.image.imageFromName("NSAdvanced") }
---     }):canCustomize(true)
---       :autosaves(true)
---       :selectedItem("select2")
---       :setCallback(function(...)
---                         print("a", inspect(table.pack(...)))
---                    end)
---
--- t.attachToolbar(a)
--- ~~~
---
--- Notes:
---  * This module is supported in OS X versions prior to 10.10 (for the Hammerspoon console only), even though its parent `hs.webview` is not. To load this module directly, use `require("hs.webview.toolbar")` instead of relying on module auto-loading.
---  * Toolbar items are rendered in the order they are supplied, although if the toolbar is marked as customizable, the user may have changed the order.

local USERDATA_TAG = "hs.webview.toolbar"
local module       = require(USERDATA_TAG.."_internal")
local toolbarMT    = hs.getObjectMetatable(USERDATA_TAG)

-- required for image support
require("hs.image")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.systemToolbarItems = ls.makeConstantsTable(module.systemToolbarItems)
module.itemPriorities     = ls.makeConstantsTable(module.itemPriorities)


--- hs.webview.toolbar:addItems(toolbarTable) -> toolbarObject
--- Method
--- Add one or more toolbar items to the toolbar
---
--- Parameters:
---  * `toolbarTable` - a table describing a single toolbar item, or an array of tables, each describing a separate toolbar item, to be added to the toolbar.
---
--- Returns:
---  * the toolbarObject
---
--- Notes:
--- * Each toolbar item is defined as a table of key-value pairs.  The following list describes the valid keys used when describing a toolbar item for this method, the constructor [hs.webview.toolbar.new](#new), and the [hs.webview.toolbar:modifyItem](#modifyItem) method.  Note that the `id` field is **required** for all three uses.
---   * `id`           - A unique string identifier required for each toolbar item and group.  This key cannot be changed after an item has been created.
---   * `allowedAlone` - a boolean value, default true, specifying whether or not the toolbar item can be added to the toolbar, programmatically or through the customization panel, (true) or whether it can only be added as a member of a group (false).
---   * `default`      - a boolean value, default matching the value of `allowedAlone` for this item, indicating whether or not this toolbar item or group should be displayed in the toolbar by default, unless overridden by user customization or a saved configuration (when such options are enabled).
---   * `enable`       - a boolean value, default true, indicating whether or not the toolbar item is active (and can be clicked on) or inactive and greyed out.  This field is ignored when applied to a toolbar group; apply it to the group members instead.
---   * `fn`           - a callback function, or false to remove, specific to the toolbar item. This property is ignored if assigned to the button group. This function will override the toolbar callback defined with [hs.webview.toolbar:setCallback](#setCallback) for this specific item. The function should expect three (four, if the item is a `searchfield`) arguments and return none.  See [hs.webview.toolbar:setCallback](#setCallback) for information about the callback's arguments.
---   * `groupMembers` - an array (table) of strings specifying the toolbar item ids that are members of this toolbar item group.  If set to false, this field is removed and the item is reset back to being a regular toolbar item.  Note that you cannot change a currently visible toolbar item to or from being a group; it must first be removed from active toolbar with [hs.webview.toolbar:removeItem](#removeItem).
---   * `image`        - an `hs.image` object, or false to remove, specifying the image to use as the toolbar item's icon when icon's are displayed in the toolbar or customization panel. This key is ignored for a toolbar item group, but not for it's individual members.
---   * `label`        - a string label, or false to remove, for the toolbar item or group when text is displayed in the toolbar or in the customization panel. For a toolbar item, the default is the `id` string; for a group, the default is `false`. If a group has a label assigned to it, the group label will be displayed for the group of items it contains. If a group does not have a label, the individual items which make up the group will each display their individual labels.
---   * `priority`     - an integer value used to determine toolbar item order and which items are displayed or put into the overflow menu when the number of items in the toolbar exceed the width of the window in which the toolbar is attached. Some example values are provided in the [hs.webview.toolbar.itemPriorities](#itemPriorities) table. If a toolbar item is in a group, it's priority is ignored and the item group is ordered by the item group's priority.
---   * `searchfield`  - a boolean (default false) specifying whether or not this toolbar item is a search field. If true, the following additional keys are allowed:
---     * `searchHistory`                - an array (table) of strings, specifying previous searches to automatically include in the search field menu, if `searchPredefinedMenuTitle` is not false
---     * `searchHistoryAutosaveName`    - a string specifying the key name to save search history with in the application deafults (accessible through `hs.settings`). If this value is set, search history will be maintained through restarts of Hammerspoon.
---     * `searchHistoryLimit`           - the maximum number of items to store in the search field history.
---     * `searchPredefinedMenuTitle`    - a string or boolean specifying how a predefined list of search field "response" should be included in the search field menu. If this item is `true`, this list of items specified for `searchPredefinedSearches` will be displayed in a submenu with the title "Predefined Searches". If this item is a string, the list of items will be displayed in a submenu with the title specified by this string value. If this item is `false`, then the search field menu will only contain the items specified in `searchPredefinedSearches` and no search history will be included in the menu.
---     * `searchPredefinedSearches`     - an array (table) of strings specifying the items to be listed in the predefined search submenu. If set to false, any existing menu will be removed and the search field menu will be reset to the default.
---     * `searchReleaseFocusOnCallback` - a boolean, default false, specifying whether or not focus leaves the search field text box when the callback is invoked. Setting this to true can be useful if you want subsequent keypresses to be caught by the webview after reacting to the value entered into the search field by the user.
---     * `searchText`                   - a string specifying the text to display in the search field.
---     * `searchWidth`                  - the width of the search field text entry box.
---   * `selectable`   - a boolean value, default false, indicating whether or not this toolbar item is selectable (i.e. highlights, like a selected tab) when clicked on. Only one selectable toolbar item can be highlighted at a time, and you can get or set/reset the selected item with [hs.webview.toolbar:selectedItem](#selectedItem).
---   * `tag`          - an integer value which can be used for own purposes; has no affect on the visual aspect of the item or its behavior.
---   * `tooltip`      - a string label, or false to remove, which is displayed as a tool tip when the user hovers the mouse over the button or button group. If a button is in a group, it's tooltip is ignored in favor of the group tooltip.
toolbarMT.addItems = function(self, ...)
    local args = table.pack(...)
    if args.n == 1 then
        if #args[1] > 1 then -- it's already a table of tables
            args = args[1]
        end
    end
    args.n = nil
    return self:_addItems(args)
end

--- hs.webview.toolbar:removeItem(index | identifier) -> toolbarObject
--- Method
--- Remove the toolbar item at the index position specified, or with the specified identifier, if currently present in the toolbar.
---
--- Parameters:
---  * `index` - the numerical position of the toolbar item to remove.
---  * `identifier` - the identifier of the toolbar item to remove, if currently active in the toolbar
---
--- Returns:
---  * the toolbar object
---
--- Notes:
---  * the toolbar position must be between 1 and the number of currently active toolbar items.
toolbarMT.removeItem = function(self, item)
    if type(item) == "string" then
        local found = false
        for i, v in ipairs(self:items()) do
            if v == item then
                item  = i
                found = true
                break
            end
        end
        if not found then return self end
    end
    return self:_removeItemAtIndex(item)
end

-- Return Module Object --------------------------------------------------

return module
