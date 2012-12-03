-- Author      : Kurapica
-- Create Date : 9/6/2008
-- ChangeLog   :
--				2010.01.11	When add a tab, do FixHeight for the container, Add FixHeight function to TabButton
--				2010.11.25	Fix for CTM
--				2011/03/13	Recode as class
--              2011/07/18  Using Frame instead of ScrollForm

---------------------------------------------------------------------------------------------------------------------------------------
--- TabGroup is a widget type using for create TabFrame
-- <br><br>inherit <a href="..\Base\Frame.html">Frame</a> For all methods, properties and scriptTypes
-- @name TabGroup
-- @class table
-- @field UseCloseBtn Whether the close button is using or not
-- @field TabNum the TabButtons' count, readonly
---------------------------------------------------------------------------------------------------------------------------------------

-- Check Version
local version = 10
if not IGAS:NewAddon("IGAS.Widget.TabGroup", version) then
	return
end

class "TabGroup"
	inherit "Frame"

    BUTTON_HEIGHT = 24
	BUTTON_MINWIDTH = 100

    ---------------------------------------------------------------------------------------------------------------------------------------
	--- TabButton is using as button that show on the top of the TabGroup, can only be created by TabGroup
	-- <br><br>inherit <a href="..\Base\Button.html">Button</a> For all methods, properties and scriptTypes
	-- @name TabButton
	-- @class table
	-- @field Enabled Whether the TabButton is enabled or not
	-- @field Selected Whether the TabButton is selected
	-- @field Text the text that displayed on the TabButton
	-- @field Container the Container binded to the TabButton
	---------------------------------------------------------------------------------------------------------------------------------------
    class "TabButton"
		inherit "Button"

        -- Scripts
        local _FrameBackdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 9,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        }

        local function OnClick(self)
            self:Select()
        end

        local function UpdateTabLook(self)
			local left = self:GetChild("Left")
			local right = self:GetChild("Right")
			local middle = self:GetChild("Middle")

            if self.__Selected then
                self:GetChild("Text"):SetTextColor(1,1,1)
                self:GetHighlightTexture():Hide()
                self.__Container:Show()

				left.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-ActiveTab]]
				left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, -3)
				left:SetTexCoord(0, 0.15625, 0, 1.0)

				right.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-ActiveTab]]
				right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, -3)
				right:SetTexCoord(0.84375, 1.0, 0, 1.0)

				middle.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-ActiveTab]]
				middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
            else
                self:GetChild("Text"):SetTextColor(1,0.82,0)
                self:GetHighlightTexture():Show()
                self.__Container:Hide()

				left.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
				left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
				left:SetTexCoord(0, 0.15625, 0, 1.0)

				right.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
				right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
				right:SetTexCoord(0.84375, 1.0, 0, 1.0)

				middle.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
				middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
			end

            if self.__Disabled then
                self:GetChild("Text"):SetTextColor(0.5,0.5,0.5)
                self:GetHighlightTexture():Hide()
            end
        end

		------------------------------------------------------
		-- Script
		------------------------------------------------------
		------------------------------------
		--- ScriptType, Run when the TabButton is selected
		-- @name TabButton:OnTabSelect
		-- @class function
		-- @usage function TabButton:OnTabSelect()<br>
		--    -- do someting<br>
		-- end
		------------------------------------
		script "OnTabSelect"

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		------------------------------------
		--- Sets the tabButton's text
		-- @name TabButton:SetText
		-- @class function
		-- @param text the button's text
		-- @usage TabButton:SetText("Summary")
		------------------------------------
		function SetText(self, text)
			self:GetChild("Text").Text = text
			if self:GetChild("Text").Width + 20 > BUTTON_MINWIDTH then
				self.Width = self:GetChild("Text").Width + 20
			else
				self.Width = BUTTON_MINWIDTH
			end
		end

		------------------------------------
		--- Gets the tabButton's text
		-- @name TabButton:GetText
		-- @class function
		-- @return the button's text
		-- @usage TabButton:GetText()
		------------------------------------
		function GetText(self)
			return self:GetChild("Text").Text
		end

		------------------------------------
		--- Select the TabButton
		-- @name TabButton:Select
		-- @class function
		-- @usage TabButton:Select()
		------------------------------------
		function Select(self)
			if self.__Disabled or self.__Selected then
				return
			end

			self.__Selected = true
			UpdateTabLook(self)

			-- Others
			local parent = self.Parent

			for i = 1, parent.__TabNum do
				if i ~= self.__TabIndex and parent:GetChild("TabButton"..i) then
					parent:GetChild("TabButton"..i).Selected = false
				end
			end

			self:Fire("OnTabSelect")
		end

		------------------------------------
		--- Whether the TabButton is selected
		-- @name TabButton:IsSelected
		-- @class function
		-- @return true if the TabButton is selected
		-- @usage TabButton:IsSelected()
		------------------------------------
		function IsSelected(self)
			return self.__Selected
		end

		------------------------------------
		--- Disable the TabButton
		-- @name TabButton:Disable
		-- @class function
		-- @usage TabButton:Disable()
		------------------------------------
		function Disable(self)
			local parent = self.Parent
			local selTab

			self.__Disabled = true

			if self.__Selected then
				for i = 1, parent.__TabNum do
					if i ~= self.__TabIndex then
						selTab = parent:GetChild("TabButton"..i)

						if selTab and selTab:IsEnabled() then
							selTab:Select()
							break
						end
					end
				end
			end

			UpdateTabLook(self)
		end

		------------------------------------
		--- Enable the TabButton
		-- @name TabButton:Enable
		-- @class function
		-- @usage TabButton:Enable()
		------------------------------------
		function Enable(self)
			self.__Disabled = false
			UpdateTabLook(self)
		end

		------------------------------------
		--- Whether the TabButton is enabled
		-- @name TabButton:IsEnabled
		-- @class function
		-- @return true if the TabButton is enabled
		-- @usage TabButton:IsEnabled()
		------------------------------------
		function IsEnabled(self)
			return (not self.__Disabled)
		end

		-- Dispose, release resource
		function Dispose(self)
			local parent = self.Parent
			local selTab

			self:Disable()

			-- Parent Map
			selTab = parent:GetChild("TabButton"..(self.__TabIndex+1))

			if selTab then
				if self.__TabIndex == 1 then
					selTab:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
				else
					selTab:SetPoint("BOTTOMLEFT", parent:GetChild("TabButton"..(self.__TabIndex-1)), "BOTTOMRIGHT", 0, 0)
				end
			end

			self:Hide()
			self.__Container:Dispose()

			parent:RemoveChild(self)

			if parent.__TabNum > self.__TabIndex then
				for i = self.__TabIndex + 1, parent.__TabNum do
					parent:GetChild("TabButton"..i).__TabIndex = i-1
					parent:GetChild("TabButton"..i).Name = "TabButton"..(i - 1)
				end
			end

			parent.__TabNum = parent.__TabNum - 1

			-- Call super's dispose
			return Button.Dispose(self)
		end

		--[[----------------------------------
		--- Adjust the TabButton's container's height
		-- @name TabButton:FixHeight
		-- @class function
		-- @usage TabButton:FixHeight()
		------------------------------------
		function FixHeight(self)
			self.__Container:FixHeight()
		end--]]

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		-- Enabled
		property "Enabled" {
			Set = function(self, flag)
				if flag then
					self:Enable()
				else
					self:Disable()
				end
			end,

			Get = function(self)
				return (self:IsEnabled() and true) or false
			end,

			Type = Boolean,
		}
		-- Selected
		property "Selected" {
			Set = function(self, flag)
				if flag then
					self:Select()
				else
					self.__Selected = false
					UpdateTabLook(self)
				end
			end,

			Get = function(self)
				return (self:IsSelected() and true) or false
			end,

			Type = Boolean,
		}
		-- Text
		property "Text" {
			Set = function(self, text)
				self:SetText(text)
			end,

			Get = function(self)
				return self:GetText()
			end,

			Type = LocaleString,
		}
		-- Container
		property "Container" {
			Get = function(self)
				--return self.__Container.Container
				return self.__Container
			end,
		}
		-- Index
		property "Index" {
			Get = function(self)
				return self.__TabIndex
			end,
		}

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
        function TabButton(name, parent)
            local tab = Button(name,parent)
			tab:RegisterForClicks("AnyDown")
            tab.Width = BUTTON_MINWIDTH
            tab.Height = BUTTON_HEIGHT

            tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
            local t = tab:GetHighlightTexture()
            t:SetBlendMode("ADD")
            t:SetPoint("TOPLEFT",tab,"TOPLEFT",2,-7)
            t:SetPoint("BOTTOMRIGHT",tab,"BOTTOMRIGHT",-2,-3)

            local left = Texture("Left", tab, "BACKGROUND")
            local middle = Texture("Middle", tab, "BACKGROUND")
            local right = Texture("Right", tab, "BACKGROUND")
            local text = FontString("Text", tab, "BACKGROUND","GameFontNormalSmall")

            text:SetPoint("LEFT",tab,"LEFT",5,-4)
            text:SetPoint("RIGHT",tab,"RIGHT",-5,-4)
            text:SetHeight(18)
            text:SetText("NewTab")

			left.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
			left.Width = 20
			left.Height = BUTTON_HEIGHT
			left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT")
			left:SetTexCoord(0, 0.15625, 0, 1.0)

			right.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
			right.Width = 20
			right.Height = BUTTON_HEIGHT
			right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT")
			right:SetTexCoord(0.84375, 1.0, 0, 1.0)

			middle.TexturePath = [[Interface\OptionsFrame\UI-OptionsFrame-InActiveTab]]
			middle.Height = BUTTON_HEIGHT
			middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT")
			middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
			middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)

            -- Container
            --local container = ScrollForm(nil, parent.__Root:GetChild("Body"))
			local container = Frame(nil, parent.__Root:GetChild("Body"))
			container:SetBackdrop(_FrameBackdrop)
			container:SetBackdropColor(0, 0, 0)
			container:SetBackdropBorderColor(0.4, 0.4, 0.4)
			container.MouseWheelEnabled = true
			container.MouseEnabled = true

            tab.__Container = container

			tab.OnClick = tab.OnClick + OnClick

            -- Parent map
            parent.__TabNum = (parent.__TabNum or 0) + 1
            tab.__TabIndex = parent.__TabNum

			--- Anchor
			if tab.__TabIndex == 1 then
				tab:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
			else
				tab:SetPoint("BOTTOMLEFT", parent:GetChild("TabButton"..(tab.__TabIndex-1)), "BOTTOMRIGHT", 0, 0)
			end
			container:SetAllPoints(parent.__Root:GetChild("Body"))
			--container:FixHeight()
			container:Hide()

            return tab
        end
    endclass "TabButton"

    ------------------------------------------------------
	--------------------- TabGroup  -------------------
	------------------------------------------------------

    -- Scripts
    local function CloseButtOnClick(self)
		if self.Parent.InDesignMode then
			return
		end
		self.Parent:Fire("OnTabClose")
        if self.Parent.__HeaderContainer.__SelectTab then
            self.Parent.__HeaderContainer.__SelectTab:Dispose()
        end
        if self.Parent.__HeaderContainer.__TabNum == 0 then
            self.Parent.__HeaderContainer.__SelectTab = nil
            self:Hide()
        end
    end

	local function UpdateTab(self)
		local header = self:GetChild("Header")
		local tabCon = self.__HeaderContainer
		local width = 0

		-- Width
		if tabCon.__TabNum and tabCon.__TabNum > 0 then
			for i = 1, tabCon.__TabNum do
				width = width + tabCon:GetChild("TabButton"..i).Width
			end
			tabCon.Width = width
		else
			tabCon.Width = header.Width
		end

		if not tabCon.__TabNum or tabCon.__TabNum <= 0 or tabCon.Width <= header.Width then
			tabCon:SetPoint("TOPLEFT",header,"TOPLEFT",0,0)
			tabCon.__OffSet = 0
			self:GetChild("LeftBtn"):Hide()
			self:GetChild("RightBtn"):Hide()
		else
			self:GetChild("LeftBtn"):Show()
			self:GetChild("RightBtn"):Show()
		end
	end

	local function OnSizeChanged(self)
		UpdateTab(self.Parent.__Root)
	end

    local function OnSizeChanged2(self)
        UpdateTab(self.Parent)
    end

    local function OnTabSelect(self)
        local parent = self.Parent

        if parent.__SelectTab ~= self then
            parent.__Root:Fire("OnTabChange", parent.__SelectTab, self)
            parent.__SelectTab = self
        end
    end

	local function OnLeftBtnClk(self)
		local header = self.Parent:GetChild("Header")
		local tabCon = self.Parent.__HeaderContainer

		tabCon.__OffSet = (tabCon.__OffSet or 0) - (header.Width/2)
		if tabCon.__OffSet < 0 then
			tabCon.__OffSet = 0
		end
		tabCon:SetPoint("TOPLEFT",header,"TOPLEFT",0-tabCon.__OffSet,0)
	end

	local function OnRightBtnClk(self)
		local header = self.Parent:GetChild("Header")
		local tabCon = self.Parent.__HeaderContainer

		tabCon.__OffSet = (tabCon.__OffSet or 0) + (header.Width/2)
		if tabCon.__OffSet > (tabCon.Width - header.Width) then
			tabCon.__OffSet = tabCon.Width - header.Width
		end
		tabCon:SetPoint("TOPLEFT",header,"TOPLEFT",0-tabCon.__OffSet,0)
	end

	------------------------------------------------------
	-- Script
	------------------------------------------------------
	------------------------------------
	--- ScriptType, Run when the an Tab is selected
	-- @name TabGroup:OnTabChange
	-- @class function
	-- @param oldTab
	-- @param newTab
	-- @usage function TabGroup:OnTabChange(oldTab, newTab)<br>
	--    -- do someting<br>
	-- end
	------------------------------------
	script "OnTabChange"

	------------------------------------
	--- ScriptType, Run when an tab is closed
	-- @name TabGroup:OnTabClose
	-- @class function
	-- @usage function TabGroup:OnTabClose()<br>
	--    -- do someting<br>
	-- end
	------------------------------------
	script "OnTabClose"

	------------------------------------------------------
	-- Method
	------------------------------------------------------

	-- Dispose, release resource
	function Dispose(self)
		local header = self.__HeaderContainer

		if header.__TabNum and header.__TabNum > 0 then
			for i = header.__TabNum, 1, -1 do
				header:GetChild("TabButton"..i):Dispose()
			end
		end

		-- Call super's dispose
		Frame.Dispose(self)
	end

	------------------------------------
	--- Add or get a TabButton with the given text
	-- @name TabGroup:AddTab
	-- @class function
	-- @param text the text to be displayed on the TabButton
	-- @return the TabButton that created
	-- @usage TabGroup:AddTab("Summary")
	------------------------------------
	function AddTab(self, name)
		if not name or type(name) ~= "string" then
			error("Usage: TabGroup:AddTab(name) : name - must be a string.", 2)
		end

		tab = TabButton(nil, self.__HeaderContainer)
		tab.Text = name

		tab.OnSizeChanged = OnSizeChanged
		tab.OnTabSelect = OnTabSelect

		-- If first use, select the first tab.
		if tab.__TabIndex == 1 then
			tab:Select()
			if not self.__HideCloseBtn then
				self:GetChild("CloseBtn"):Show()
			end
		end

		UpdateTab(self)

		return tab
	end

	------------------------------------
	--- Remove a TabButton with the given index
	-- @name TabGroup:RemoveTabByIndex
	-- @class function
	-- @param index the index of a Tab Button
	-- @usage TabGroup:RemoveTabByIndex(1)
	------------------------------------
	function RemoveTabByIndex(self, id)
		if type(id) ~= "number" then
			error("Usage: TabGroup:RemoveTabByIndex(index) : index - must be a number.", 2)
		end

		id = floor(id)

		local header = self.__HeaderContainer
		if header.__TabNum and header.__TabNum >= id then
			header:GetChild("TabButton"..id):Dispose()
			UpdateTab(self)
		end
	end

	------------------------------------
	--- Get a TabButton with the given index
	-- @name TabGroup:GetTabByIndex
	-- @class function
	-- @param index the index of a Tab Button
	-- @return the TabButton object
	-- @usage TabGroup:GetTabByIndex(1)
	------------------------------------
	function GetTabByIndex(self, id)
		if type(id) ~= "number" then
			error("Usage: TabGroup:RemoveTabByIndex(index) : index - must be a number.", 2)
		end

		id = floor(id)

		local header = self.__HeaderContainer
		if header.__TabNum and header.__TabNum >= id then
			return header:GetChild("TabButton"..id)
		end

		return nil
	end

	------------------------------------
	--- Get the select TabButton
	-- @name TabGroup:GetSelectTab
	-- @class function
	-- @return the TabButton object
	-- @usage TabGroup:GetSelectTab()
	------------------------------------
	function GetSelectTab(self)
		return self.__HeaderContainer.__SelectTab
	end

	------------------------------------
	--- Show the close button
	-- @name TabGroup:ShowCloseBtn
	-- @class function
	-- @usage TabGroup:ShowCloseBtn()
	------------------------------------
	function ShowCloseBtn(self)
		self.__HideCloseBtn = false
		if self.__HeaderContainer.__TabNum > 0 then
			self:GetChild("CloseBtn"):Show()
		end
	end

	------------------------------------
	--- Hide the close button
	-- @name TabGroup:HideCloseBtn
	-- @class function
	-- @usage TabGroup:HideCloseBtn()
	------------------------------------
	function HideCloseBtn(self)
		self.__HideCloseBtn = true
		self:GetChild("CloseBtn"):Hide()
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	property "UseCloseBtn" {
		Set = function(self, flag)
			if flag then
				self:ShowCloseBtn()
			else
				self:HideCloseBtn()
			end
		end,

		Get = function(self)
			return (not self.__HideCloseBtn and true) or false
		end,

		Type = Boolean,
	}

	property "TabNum" {
		Get = function(self)
			return self.__HeaderContainer.__TabNum or 0
		end,

		Type = Number,
	}

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
    function TabGroup(name, parent)
		local frame = Frame(name,parent)

		local closeButton = NormalButton("CloseBtn",frame)
		closeButton:SetPoint("TOPRIGHT",frame,"TOPRIGHT")
        closeButton:Hide()
        closeButton.Style = "CLOSE"
		closeButton.OnClick = CloseButtOnClick

        local btnScrollRight = Button("RightBtn", frame)
        btnScrollRight:SetWidth(32)
        btnScrollRight:SetHeight(32)
        btnScrollRight:ClearAllPoints()
        btnScrollRight:SetPoint("TOP", frame, "TOP", 0, 0)
        btnScrollRight:SetPoint("RIGHT", closeButton, "LEFT", 0, 0)
        btnScrollRight:SetNormalTexture("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Up.blp")
        btnScrollRight:SetPushedTexture("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Down.blp")
        btnScrollRight:SetDisabledTexture("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Disabled.blp")
        btnScrollRight:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight.blp", "ADD")
        btnScrollRight:Hide()
		btnScrollRight.OnClick = OnRightBtnClk

        local btnScrollLeft = Button("LeftBtn", frame)
        btnScrollLeft:SetWidth(32)
        btnScrollLeft:SetHeight(32)
        btnScrollLeft:ClearAllPoints()
        btnScrollLeft:SetPoint("TOP", frame, "TOP", 0, 0)
        btnScrollLeft:SetPoint("RIGHT", btnScrollRight, "LEFT", 0, 0)
        btnScrollLeft:SetNormalTexture("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Up.blp")
        btnScrollLeft:SetPushedTexture("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Down.blp")
        btnScrollLeft:SetDisabledTexture("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Disabled.blp")
        btnScrollLeft:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight.blp", "ADD")
        btnScrollLeft:Hide()
		btnScrollLeft.OnClick = OnLeftBtnClk

        local header = ScrollFrame("Header",frame)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		header:SetPoint("RIGHT", btnScrollLeft, "LEFT", 0, 0)
        header.Height = BUTTON_HEIGHT
		header.MouseEnabled = true
        header.OnSizeChanged = OnSizeChanged2

        local headerContainer = Frame("Container", header)
        header:SetScrollChild(headerContainer)
		headerContainer:SetPoint("TOPLEFT",header,"TOPLEFT",0,0)
        headerContainer.Height = header.Height
        headerContainer.Width = header.Width
        headerContainer.__TabNum = 0

		local body = Frame("Body", frame)
		body:SetPoint("LEFT", frame, "LEFT", 0,0)
		body:SetPoint("RIGHT", frame, "RIGHT", 0,0)
		body:SetPoint("BOTTOM", frame, "BOTTOM", 0,0)
		body:SetPoint("TOP", header, "BOTTOM", 0,0)

        frame.__HeaderContainer = headerContainer
        headerContainer.__Root = frame

        return frame
    end

	------------------------------------------------------
	-- __call
	------------------------------------------------------
	function __call(self, index)
		if type(index) == "number" then
			return GetTabByIndex(self, index)
		end
	end
endclass "TabGroup"