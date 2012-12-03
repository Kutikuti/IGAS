-- Author      : Kurapica
-- Create Date : 5/4/2012
-- ChangeLog
--               2012/07/18 Support nonRegion object

----------------------------------------------------------------------------------------------------------------------------------------
--- LayoutPanel
-- <br><br>inherit <a href="..\Base\Frame.html">Frame</a> For all methods, properties and scriptTypes
-- @name LayoutPanel
----------------------------------------------------------------------------------------------------------------------------------------

local version = 5
if not IGAS:NewAddon("IGAS.Widget.LayoutPanel", version) then
	return
end

class "LayoutPanel"
	inherit "Frame"

	import "System.Reflector"

	_Use_ShortCut = true

	_Error_Widget = "%swidget not existed."
	_Error_NotRegion = "%swidget must be a region object."
	_Error_Number = "%s%s must be a number, got %s."
	_Error_Percent = "%s%s must be 0 - 100."
	_Error_Zero = "%s%s can't be less than 0."
	_Error_Size = "%s%s can't be greater than parent's %s."
	_Error_Combine = "%sthe settings are oversize."

	local function CalcMixValue(self, param, value)
		return floor(self[param] * floor(value * 100 % 100) / 100) + floor(value)
	end

	local function ValidateSet(self, index, prefix, selfParam,
			startName, startUnitName, endName, endUnitName, sizeName, sizeUnitName,
			startValue, startUnit, endValue, endUnit, sizeValue, sizeUnit)
		local size = self[selfParam]
		local obj = GetWidget(self, index)
		local startFunc, endFunc, sizeFunc
		local minSize, remainPct, realSize

		prefix = prefix or ""
		remainPct = 100
		realSize = 0

		if obj and Reflector.ObjectIsClass(obj, Region) then
			-- Check start
			if startName then
				if type(startValue) ~= "number" then
					error(_Error_Number:format(prefix, startName, type(startValue)), 3)
				end

				startUnit = Reflector.Validate(Unit, startUnit, startUnitName, prefix, 1)

				if startUnit == _PERCENT then
					if startValue < 0 or startValue > 100 then
						error(_Error_Percent:format(prefix, startName), 3)
					end

					remainPct = remainPct - startValue
					startFunc = function() return floor(self[selfParam] * startValue / 100) end
				elseif startUnit == _PIXEL then
					if startValue < 0 then
						error(_Error_Zero:format(prefix, startName), 3)
					elseif startValue > size then
						error(_Error_Size:format(prefix, startName, selfParam), 3)
					end

					startValue = floor(startValue)
					realSize = realSize + startValue
					startFunc = function() return startValue end
				elseif startUnit == _MIX then
					if startValue < 0 then
						error(_Error_Zero:format(prefix, startName), 3)
					end

					local calc = function() return CalcMixValue(self, selfParam, startValue) end

					if calc() > size then
						error(_Error_Size:format(prefix, startName, selfParam), 3)
					end

					remainPct = remainPct - floor(startValue * 100 % 100)
					realSize = realSize + floor(startValue)
					startFunc = calc
				end
			end

			-- Check end
			if endName then
				if type(endValue) ~= "number" then
					error(_Error_Number:format(prefix, endName, type(endValue)), 3)
				end

				endUnit = Reflector.Validate(Unit, endUnit, endUnitName, prefix, 1)

				if endUnit == _PERCENT then
					if endValue < 0 or endValue > 100 then
						error(_Error_Percent:format(prefix, endName), 3)
					end
					remainPct = remainPct - endValue
					endFunc = function() return floor(self[selfParam] * endValue / 100) end
				elseif endUnit == _PIXEL then
					if endValue < 0 then
						error(_Error_Zero:format(prefix, endName), 3)
					elseif endValue > size then
						error(_Error_Size:format(prefix, endName, selfParam), 3)
					end
					endValue = floor(endValue)
					realSize = realSize + endValue
					endFunc = function() return endValue end
				elseif endUnit == _MIX then
					if endValue < 0 then
						error(_Error_Zero:format(prefix, endName), 3)
					end

					local calc = function() return CalcMixValue(self, selfParam, endValue) end

					if calc() > size then
						error(_Error_Size:format(prefix, endName, selfParam), 3)
					end

					remainPct = remainPct - floor(endValue * 100 % 100)
					realSize = realSize + floor(endValue)
					endFunc = calc
				end
			end

			-- Check size
			if sizeName then
				if type(sizeValue) ~= "number" then
					error(_Error_Number:format(prefix, sizeName, type(sizeValue)), 3)
				end

				sizeUnit = Reflector.Validate(Unit, sizeUnit, sizeUnitName, prefix, 1)

				if sizeUnit == _PERCENT then
					if sizeValue < 0 or sizeValue > 100 then
						error(_Error_Percent:format(prefix, sizeName), 3)
					end
					remainPct = remainPct - sizeValue
					sizeFunc = function() return floor(self[selfParam] * sizeValue / 100) end
				elseif sizeUnit == _PIXEL then
					if sizeValue < 0 then
						error(_Error_Zero:format(prefix, sizeName), 3)
					elseif sizeValue > size then
						error(_Error_Size:format(prefix, sizeName, selfParam), 3)
					end
					sizeValue = floor(sizeValue)
					realSize = realSize + sizeValue
					sizeFunc = function() return sizeValue end
				elseif sizeUnit == _MIX then
					if sizeValue < 0 then
						error(_Error_Zero:format(prefix, sizeName), 3)
					end

					local calc = function() return CalcMixValue(self, selfParam, sizeValue) end

					if calc() > size then
						error(_Error_Size:format(prefix, sizeName, selfParam), 3)
					end

					remainPct = remainPct - floor(sizeValue * 100 % 100)
					realSize = realSize + floor(sizeValue)
					sizeFunc = calc
				end
			end

			if not startFunc then
				startFunc = function() return floor(self[selfParam] - endFunc() - sizeFunc()) end
			elseif not sizeFunc then
				sizeFunc = function() return floor(self[selfParam] - endFunc() - startFunc()) end
			end

			-- Final check
			if startFunc() < 0 or sizeFunc() < 0 or startFunc() + sizeFunc() > size then
				error(_Error_Combine:format(prefix), 3)
			end

			if realSize > 0 then
				minSize = ceil(realSize * 100 / remainPct)
			end

			self.__NeedUpdateMinSize = true

			if selfParam == "Width" then
				obj.__Layout_Left = startFunc
				obj.__Layout_Width = sizeFunc
				obj.__Layout_MinWidth = minSize
			elseif selfParam == "Height" then
				obj.__Layout_Top = startFunc
				obj.__Layout_Height = sizeFunc
				obj.__Layout_MinHeight = minSize
			end
		elseif obj then
			error(_Error_NotRegion:format(prefix), 3)
		else
			error(_Error_Widget:format(prefix), 3)
		end
	end

	local function ValidateWidgets(self)
		local widget

		for i = #(self.__LayoutItems), 1, -1 do
			widget = self.__LayoutItems[i]

			if not Reflector.GetObjectClass(widget) then
				tremove(self.__LayoutItems, i)
			end
		end
	end

	------------------------------------------------------
	-- Enum
	------------------------------------------------------
	_PERCENT = "PERCENT"
	_PIXEL = "PIXEL"
	_MIX = "MIX"

	enum "Unit" {
		PCT = _PERCENT,
		PX = _PIXEL,
		MIX = _MIX,
	}

	------------------------------------------------------
	-- Script
	------------------------------------------------------


	------------------------------------------------------
	-- Method
	------------------------------------------------------

	------------------------------------
	--- Add Widget to the panel
	-- @name LayoutPanel:AddWidget
	-- @class function
	-- @param widget
	-- @return index
	------------------------------------
	function AddWidget(self, widget)
		ValidateWidgets(self)

		if widget and (Reflector.ObjectIsClass(widget, Region) or Reflector.ObjectIsClass(widget, VirtualUIObject)) then
			if self:GetChild(widget.Name) == widget then
				for i = 1, #(self.__LayoutItems) do
					if self.__LayoutItems[i] == widget then
						return i
					end
				end
			elseif self:GetChild(widget.Name) then
				error("Usage : LayoutPanel:AddWidget(widget) : a widget already existed with same name.", 2)
			end

			-- Insert the widget
			if widget.Parent ~= self then
				widget.Parent = self
			end

			tinsert(self.__LayoutItems, widget)

			return #(self.__LayoutItems)
		else
			error("Usage : LayoutPanel:AddWidget(widget) : widget must be an object of [System.Widget.Region]or [System.Widget.VirtualUIObject].", 2)
		end
	end

	------------------------------------
	--- Insert Widget to the panel
	-- @name LayoutPanel:InsertWidget
	-- @class function
	-- @param before the index to be insert
	-- @param widget
	------------------------------------
	function InsertWidget(self, before, widget)
		ValidateWidgets(self)

		-- Remap args
		if widget == nil then
			widget = before
			before = nil
		end

		if type(before) == "number" and before == #(self.__LayoutItems) + 1 then
			-- skip
		elseif before then
			local obj

			obj, before = GetWidget(self, before)

			if not before then
				error("Usage : LayoutPanel:InsertWidget([before, ]widget) : before not exist.", 2)
			end
		else
			before = #(self.__LayoutItems) + 1
		end

		if widget and (Reflector.ObjectIsClass(widget, Region) or Reflector.ObjectIsClass(widget, VirtualUIObject)) then
			if self:GetChild(widget.Name) == widget then
				for i = 1, #(self.__LayoutItems) do
					if self.__LayoutItems[i] == widget then
						return i
					end
				end
			elseif self:GetChild(widget.Name) then
				error("Usage : LayoutPanel:InsertWidget([before, ]widget) : a widget already existed with same name.", 2)
			end

			-- Insert the widget
			if widget.Parent ~= self then
				widget.Parent = self
			end

			tinsert(self.__LayoutItems, before, widget)

			return before
		else
			error("Usage : LayoutPanel:InsertWidget([before, ]widget) : widget must be an object of [System.Widget.Region]or [System.Widget.VirtualUIObject].", 2)
		end
	end

	------------------------------------
	--- Get Widget from the panel
	-- @name LayoutPanel:GetWidget
	-- @class function
	-- @param index|name index or the name that need to be removed
	-- @return widget
	-- @return index
	------------------------------------
	function GetWidget(self, index)
		if type(index) == "number" then
			index = floor(index)

			if index > 0 and index <= #(self.__LayoutItems) then
				return self.__LayoutItems[index], index
			end
		end

		if type(index) == "string" then
			index = self:GetChild(index)
		end

		if Reflector.ObjectIsClass(index, Region) or Reflector.ObjectIsClass(index, VirtualUIObject) then
			if self:GetChild(index.Name) == index then
				for i = 1, #(self.__LayoutItems) do
					if self.__LayoutItems[i] == index then
						return index, i
					end
				end
			end
		end
	end

	------------------------------------
	--- get widget's index
	-- @name LayoutPanel:GetWidgetIndex
	-- @class function
	-- @param index|name|widget
	-- @return index
	------------------------------------
	function GetWidgetIndex(self, widget)
		local _, index = GetWidget(self, widget)

		return index
	end

	------------------------------------
	--- Remove Widget to the panel
	-- @name LayoutPanel:RemoveWidget
	-- @class function
	-- @param index|name index or the name that need to be removed
	-- @param withoutDispose optional, true if need get the removed widget
	-- @return widget if withoutDispose is set to true
	------------------------------------
	function RemoveWidget(self, index, withoutDispose)
		local obj

		obj, index = GetWidget(self, index)

		if index and obj then
			tremove(self.__LayoutItems, index)

			if not withoutDispose then
				obj:Dispose()
			else
				obj.__Layout_Left = nil
				obj.__Layout_Width = nil
				obj.__Layout_MinWidth = nil
				obj.__Layout_Top = nil
				obj.__Layout_Height = nil
				obj.__Layout_MinHeight = nil

				return obj
			end
		end
	end

	------------------------------------
	--- Set Widget's left margin and right margin
	-- @name LayoutPanel:SetWidgetLeftRight
	-- @class function
	-- @param index|name index or the name
	-- @param left left margin value
	-- @param leftunit left margin's unit
	-- @param right right margin value
	-- @param rightunit right margin's unit
	-- @return panel
	------------------------------------
	function SetWidgetLeftRight(self, index, left, leftunit, right, rightunit)
		local prefix = "Usage : LayoutPanel:SetWidgetLeftRight(index||name||widget, left, leftunit, right, rightunit) : "

		ValidateSet(self, index, prefix, "Width",
			"left", "leftunit", "right", "rightunit", nil, nil,
			left, leftunit, right, rightunit, nil, nil)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWLR = SetWidgetLeftRight end

	------------------------------------
	--- Set Widget's left margin and width
	-- @name LayoutPanel:SetWidgetLeftWidth
	-- @class function
	-- @param index|name index or the name
	-- @param left left margin value
	-- @param leftunit left margin's unit
	-- @param width width value
	-- @param widthunit width unit
	-- @return panel
	------------------------------------
	function SetWidgetLeftWidth(self, index, left, leftunit, width, widthunit)
		local prefix = "Usage : LayoutPanel:SetWidgetLeftWidth(index||name||widget, left, leftunit, width, widthunit) :"

		ValidateSet(self, index, prefix, "Width",
			"left", "leftunit", nil, nil, "width", "widthunit",
			left, leftunit, nil, nil, width, widthunit)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWLW = SetWidgetLeftWidth end

	------------------------------------
	--- Set Widget's right margin and width
	-- @name LayoutPanel:SetWidgetRightWidth
	-- @class function
	-- @param index|name index or the name
	-- @param right right margin value
	-- @param rightunit right margin's unit
	-- @param width width value
	-- @param widthunit width unitv
	-- @return panel
	------------------------------------
	function SetWidgetRightWidth(self, index, right, rightunit, width, widthunit)
		local prefix = "Usage : LayoutPanel:SetWidgetRightWidth(index||name||widget, right, rightunit, width, widthunit) : "

		ValidateSet(self, index, prefix, "Width",
			nil, nil, "right", "rightunit", "width", "widthunit",
			nil, nil, right, rightunit, width, widthunit)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWRW = SetWidgetRightWidth end

	------------------------------------
	--- Set Widget's horizontal position
	-- @name LayoutPanel:SetWidgetRightWidth
	-- @class function
	-- @param index|name index or the name
	-- @param align begin|stretch|end
	------------------------------------
	-- function SetWidgetHorizontalPosition(self, index, align)end

	------------------------------------
	--- Set Widget's top margin and bottom margin
	-- @name LayoutPanel:SetWidgetTopBottom
	-- @class function
	-- @param index|name index or the name
	-- @param top top margin value
	-- @param topunit top margin's unit
	-- @param bottom bottom margin value
	-- @param bottomunit bottom margin's unit
	-- @return panel
	------------------------------------
	function SetWidgetTopBottom(self, index, top, topunit, bottom, bottomunit)
		local prefix = "Usage : LayoutPanel:SetWidgetTopBottom(index||name||widget, top, topunit, bottom, bottomunit) : "

		ValidateSet(self, index, prefix, "Height",
			"top", "topunit", "bottom", "bottomunit", nil, nil,
			top, topunit, bottom, bottomunit, nil, nil)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWTB = SetWidgetTopBottom end

	------------------------------------
	--- Set Widget's top margin and height
	-- @name LayoutPanel:SetWidgetTopHeight
	-- @class function
	-- @param index|name index or the name
	-- @param top top margin value
	-- @param topunit top margin's unit
	-- @param height height value
	-- @param heightunit height's unit
	-- @return panel
	------------------------------------
	function SetWidgetTopHeight(self, index, top, topunit, height, heightunit)
		local prefix = "Usage : LayoutPanel:SetWidgetTopHeight(index||name||widget, top, topunit, height, heightunit) : "

		ValidateSet(self, index, prefix, "Height",
			"top", "topunit", nil, nil, "height", "heightunit",
			top, topunit, nil, nil, height, heightunit)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWTH = SetWidgetTopHeight end

	------------------------------------
	--- Set Widget's top margin and height
	-- @name LayoutPanel:SetWidgetBottomHeight
	-- @class function
	-- @param index|name index or the name
	-- @param bottom top margin value
	-- @param bottomunit bottom margin's unit
	-- @param height height value
	-- @param heightunit height's unit
	-- @return panel
	------------------------------------
	function SetWidgetBottomHeight(self, index, bottom, bottomunit, height, heightunit)
		local prefix = "Usage : LayoutPanel:SetWidgetBottomHeight(index||name||widget, bottom, bottomunit, height, heightunit) : "

		ValidateSet(self, index, prefix, "Height",
			nil, nil, "bottom", "bottomunit", "height", "heightunit",
			nil, nil, bottom, bottomunit, height, heightunit)

		Layout(self)

		return self
	end

	if _Use_ShortCut then SWBH = SetWidgetBottomHeight end

	------------------------------------
	--- Set Widget's horizontal position
	-- @name LayoutPanel:SetWidgetRightWidth
	-- @class function
	-- @param index|name index or the name
	-- @param align begin|stretch|end
	------------------------------------
	-- function SetWidgetVerticalPosition(self, index, align)end

	------------------------------------
	--- Update layout
	-- @name LayoutPanel:Layout
	-- @class function
	------------------------------------
	function Layout(self)
		if self.__SuspendLayout or not self.__LayoutItems then
			return
		end

		local obj, left, top, width, height
		local minWidth, minHeight = 0, 0

		for i = 1, #(self.__LayoutItems) do
			obj = self.__LayoutItems[i]

			-- make sure not disposed and not VirtualUIObject
			if Reflector.ObjectIsClass(obj, Region) then
				-- Check MinSize
				if obj.__Layout_MinWidth and obj.__Layout_MinWidth > minWidth then
					minWidth = obj.__Layout_MinWidth
				end

				if obj.__Layout_MinHeight and obj.__Layout_MinHeight > minHeight then
					minHeight = obj.__Layout_MinHeight
				end

				-- Calculate obj's new position
				if obj.__Layout_Left or obj.__Layout_Width or obj.__Layout_Top or obj.__Layout_Height then
					left = obj.__Layout_Left and obj.__Layout_Left() or 0
					width = obj.__Layout_Width and obj.__Layout_Width() or self.Width
					top = obj.__Layout_Top and obj.__Layout_Top() or 0
					height = obj.__Layout_Height and obj.__Layout_Height() or self.Height

					if left and width and top and height then
						obj:ClearAllPoints()

						obj:SetPoint("LEFT", self, "LEFT", left, 0)
						obj:SetPoint("TOP", self, "TOP", 0, -top)

						obj.Width = width
						obj.Height = height
					end
				end
			end
		end

		if self.__NeedUpdateMinSize then
			self.__NeedUpdateMinSize = nil

			local mWidth, mHeight = self:GetMinResize()

			mWidth = mWidth or 0
			mHeight = mHeight or 0

			mWidth = mWidth > minWidth and mWidth or minWidth
			mHeight = mHeight > minHeight and mHeight or minHeight

			self:SetMinResize(minWidth, minHeight)
		end
	end

	------------------------------------
	--- stop the refresh of the LayoutPanel
	-- @name LayoutPanel:SuspendLayout
	-- @class function
	-- @usage LayoutPanel:SuspendLayout()
	------------------------------------
	function SuspendLayout(self)
		self.__SuspendLayout = true
	end

	------------------------------------
	--- resume the refresh of the LayoutPanel
	-- @name LayoutPanel:ResumeLayout
	-- @class function
	-- @usage LayoutPanel:ResumeLayout()
	------------------------------------
	function ResumeLayout(self)
		self.__SuspendLayout = nil
		Layout(self)
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	property "Count" {
		Get = function(self)
			return #(self.__LayoutItems)
		end,
	}

	------------------------------------------------------
	-- Script Handler
	------------------------------------------------------
	local function OnSizeChanged(self)
		self:Layout()
	end

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function LayoutPanel(name, parent)
		local panel = Frame(name, parent)

		panel.__LayoutItems = panel.__LayoutItems or {}

		panel.OnSizeChanged = panel.OnSizeChanged + OnSizeChanged

		return panel
	end
endclass "LayoutPanel"