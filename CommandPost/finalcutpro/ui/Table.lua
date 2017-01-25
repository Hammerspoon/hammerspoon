local log							= require("hs.logger").new("Table")
local inspect						= require("hs.inspect")
local drawing						= require("hs.drawing")


local axutils						= require("hs.finalcutpro.axutils")
local tools							= require("hs.fcpxhacks.modules.tools")
local geometry						= require("hs.geometry")
local just							= require("hs.just")

local Table = {}

function Table.matches(element)
	return element ~= nil
end

--- hs.finalcutpro.ui.Table:new(axuielement, table) -> Table
--- Function:
--- Creates a new Table
function Table:new(parent, finder)
	o = {_parent = parent, _finder = finder}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Table:uncached()
	self._uncached = true
	return self
end

function Table:parent()
	return self._parent
end

function Table:UI()
	if not self._uncached then
		return axutils.cache(self, "_ui", function()
			return self._finder()
		end,
		Table.matches)
	else
		return self._finder()
	end
end

function Table:contentUI()
	return axutils.cache(self, "_content", function()
		local ui = self:UI()
		return ui and axutils.childMatching(ui, Table.matchesContent)
	end,
	Table.matchesContent)
end

function Table.matchesContent(element)
	if element then
		local role = element:attributeValue("AXRole")
		return role == "AXOutline" or role == "AXTable"
	end
	return false
end

function Table:verticalScrollBarUI()
	local ui = self:UI()
	return ui and ui:attributeValue("AXVerticalScrollBar")
end

function Table:horizontalScrollBarUI()
	local ui = self:UI()
	return ui and ui:attributeValue("AXHorizontalScrollBar")
end

function Table:isShowing()
	return self:UI() ~= nil
end

function Table:isFocused()
	local ui = self:UI()
	return ui and ui:focused() or axutils.childWith(ui, "AXFocused", true) ~= nil
end

-- Returns the list of rows in the table
-- An optional filter function may be provided. It will be passed a single `AXRow` element
-- and should return `true` if the row should be included.
function Table:rowsUI(filterFn)
	local ui = self:contentUI()
	if ui then
		local rows = {}
		for i,child in ipairs(ui) do
			if child:attributeValue("AXRole") == "AXRow" then
				if not filterFn or filterFn(child) then
					rows[#rows + 1] = child
				end
			end
		end
		return rows
	end
	return nil
end

function Table:columnsUI()
	local ui = self:contentUI()
	if ui then
		local columns = {}
		for i,child in ipairs(ui) do
			if child:attributeValue("AXRole") == "AXColumn" then
				columns[#columns + 1] = child
			end
		end
		return columns
	end
	return nil
end

function Table:findColumnNumber(id)
	local cols = self:columnsUI()
	if cols then
		for i=1,#cols do
			if cols[i]:attributeValue("AXIdentifier") == id then
				return i
			end
		end
	end
	return nil
end

function Table:findCellUI(rowNumber, columnId)
	local rows = self:rowsUI()
	if rows and rowNumber >= 1 and rowNumber < #rows then
		local colNumber = self:findColumnNumber(columnId)
		return colNumber and rows[rowNumber][colNumber]
	end
	return nil
end

function Table:selectedRowsUI()
	local rows = self:rowsUI()
	if rows then
		local selected = {}
		for i,row in ipairs(rows) do
			if row:attributeValue("AXSelected") then
				selected[#selected + 1] = row
			end
		end
		return selected
	end
	return nil
end

function Table:viewFrame()
	local ui = self:UI()
	if ui then
		local vFrame = ui:frame()
		local vScroll = self:verticalScrollBarUI()
		if vScroll then
			local vsFrame = vScroll:frame()
			vFrame.w = vFrame.w - vsFrame.w
			vFrame.h = vsFrame.h
		else
			local hScroll = self:horizontalScrollBarUI()
			if hScroll then
				local hsFrame = hScroll:frame()
				vFrame.w = hsFrame.w
				vFrame.h = vFrame.h - hsFrame.h
			end
		end
		return vFrame
	end
	return nil
end

function Table:showRow(rowUI)
	local ui = self:UI()
	if ui and rowUI then
		local vFrame = self:viewFrame()
		local rowFrame = rowUI:frame()

		local top = vFrame.y
		local bottom = vFrame.y + vFrame.h

		local rowTop = rowFrame.y
		local rowBottom = rowFrame.y + rowFrame.h

		if rowTop < top or rowBottom > bottom then
			-- we need to scroll
			local oFrame = self:contentUI():frame()
			local scrollHeight = oFrame.h - vFrame.h

			local vValue = nil
			if rowTop < top or rowFrame.h > scrollHeight then
				vValue = (rowTop-oFrame.y)/scrollHeight
			else
				vValue = 1.0 - (oFrame.y + oFrame.h - rowBottom)/scrollHeight
			end
			local vScroll = self:verticalScrollBarUI()
			if vScroll then
				vScroll:setAttributeValue("AXValue", vValue)
			end
		end
	end
	return self
end

function Table:showRowAt(index)
	local rows = self:rowsUI()
	if rows then
		if index > 0 and index <= #rows then
			self:showRow(rows[index])
		end
	end
	return self
end

function Table:selectRow(rowUI)
	rowUI:setAttributeValue("AXSelected", true)
	return self
end

function Table:selectRowAt(index)
	local ui = self:rowsUI()
	if ui and #ui >= index then
		self:selectRow(ui[index])
	end
	return self
end

function Table:deselectRow(rowUI)
	rowUI:setAttributeValue("AXSelected", false)
	return self
end

function Table:deselectRowAt(index)
	local ui = self:rowsUI()
	if ui and #ui >= index then
		self:deselectRow(ui[index])
	end
	return self
end

-- Selects the specified rows. If `rowsUI` is `nil`, then all rows will be selected.
function Table:selectAll(rowsUI)
	rowsUI = rowsUI or self:rowsUI()
	local outline = self:contentUI()
	if rowsUI and outline then
		outline:setAttributeValue("AXSelectedRows", rowsUI)
	end
	return self
end

-- Deselects the specified rows. If `rowsUI` is `nil`, then all rows will be deselected.
function Table:deselectAll(rowsUI)
	rowsUI = rowsUI or self:selectedRowsUI()
	if rowsUI then
		for i,row in ipairs(rowsUI) do
			self:deselectRow(row)
		end
	end
	return self
end

function Table:saveLayout()
	local layout = {}
	local hScroll = self:horizontalScrollBarUI()
	if hScroll then
		layout.horizontalScrollBar = hScroll:value()
	end
	local vScroll = self:verticalScrollBarUI()
	if vScroll then
		layout.verticalScrollBar = vScroll:value()
	end
	layout.selectedRows = self:selectedRowsUI()
	
	return layout
end

function Table:loadLayout(layout)
	if layout then
		self:selectAll(layout.selectedRows)
		local vScroll = self:verticalScrollBarUI()
		if vScroll then
			vScroll:setValue(layout.verticalScrollBar)
		end
		local hScroll = self:horizontalScrollBarUI()
		if hScroll then
			hScroll:setValue(layout.horizontalScrollBar)
		end
	end
end
return Table