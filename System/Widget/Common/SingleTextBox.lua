-- Author      : Kurapica
-- Create Date : 8/03/2008 17:14
-- Change Log  :
--				2011/03/13	Recode as class

---------------------------------------------------------------------------------------------------------------------------------------
--- SingleTextBox is a widget type using to contain one line text
-- <br><br>inherit <a href="..\Base\EditBox.html">EditBox</a> For all methods, properties and scriptTypes
-- @name SingleTextBox
-- @class table
-- @field Style the style of the singletextbox: CLASSIC, LIGHT
---------------------------------------------------------------------------------------------------------------------------------------

-- Check Version
local version = 5

if not IGAS:NewAddon("IGAS.Widget.SingleTextBox", version) then
	return
end

class "SingleTextBox"
	inherit "EditBox"

    -- Style
    TEMPLATE_CLASSIC = "CLASSIC"
    TEMPLATE_LIGHT = "LIGHT"

    -- Define Block
	enum "TextBoxStyle" {
        TEMPLATE_CLASSIC,
		TEMPLATE_LIGHT,
    }

    -- Scripts
    local _FrameBackdropLight = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 9,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    }

    local function OnEscapePressed(self, ...)
	    self:ClearFocus()
    end

	local function OnEditFocusLost(self, ...)
		self:HighlightText(0, 0)
    end

    local function OnEditFocusGained(self, ...)
	    self:HighlightText()
    end

	------------------------------------------------------
	-- Script
	------------------------------------------------------

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	------------------------------------
	--- Sets the singletextbox's style
	-- @name SingleTextBox:SetStyle
	-- @class function
	-- @param style the style of the singletextbox : CLASSIC, LIGHT
	-- @usage SingleTextBox:SetStyle("LIGHT")
	------------------------------------
	function SetStyle(self, style)
		local t

		-- Check Style
		if not style or type(style) ~= "string" then
			return
		end

		if (not TextBoxStyle[style]) or style == self.__Style then
			return
		end

		-- Change Style
		if style == TEMPLATE_CLASSIC then
			self:SetBackdrop(nil)

			local left = Texture("LEFT", self, "BACKGROUND")
			left.Visible = true
			left.Width = 8
			left:SetTexture("Interface\\Common\\Common-Input-Border")
			left:SetTexCoord(0, 0.0625, 0, 0.625)
			left:SetPoint("TOPLEFT", self, "TOPLEFT", -5, 0)
			left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -5, 0)

			local right = Texture("RIGHT", self, "BACKGROUND")
			right.Visible = true
			right.Width = 8
			right:SetTexture("Interface\\Common\\Common-Input-Border")
			right:SetTexCoord(0.9375, 1.0, 0, 0.625)
			right:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
			right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

			local middle = Texture("MIDDLE", self, "BACKGROUND")
			middle.Visible = true
			middle.Width = 10
			middle:SetTexture("Interface\\Common\\Common-Input-Border")
			middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
			middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
			middle:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
			middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
			middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		elseif style == TEMPLATE_LIGHT then
			if self:GetChild("LEFT") then
				self:GetChild("LEFT"):Hide()
			end
			if self:GetChild("RIGHT") then
				self:GetChild("RIGHT"):Hide()
			end
			if self:GetChild("MIDDLE") then
				self:GetChild("MIDDLE"):Hide()
			end

			self:SetBackdrop(_FrameBackdropLight)
			self:SetBackdropColor(0, 0, 0, 1)
		end
	end

	------------------------------------
	--- Gets the singletextbox's style
	-- @name SingleTextBox:GetStyle
	-- @class function
	-- @return the style of the singletextbox : CLASSIC, LIGHT
	-- @usage SingleTextBox:GetStyle("LIGHT")
	------------------------------------
	function GetStyle(self)
		return self.__Style or TEMPLATE_NONE
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	-- Style
	property "Style" {
		Set = function(self, style)
			self:SetStyle(style)
		end,

		Get = function(self)
			return self:GetStyle()
		end,

		Type = TextBoxStyle,
	}

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
    function SingleTextBox(name, parent)
		-- New Frame
		local txtBox = EditBox(name, parent)
		txtBox.Height = 25
		txtBox.FontObject = "GameFontNormal"
		txtBox:SetTextInsets(4 , -4, 0, 0)
        txtBox.MouseEnabled = true
        txtBox.AutoFocus = false
		txtBox:SetBackdrop(_FrameBackdropLight)
        txtBox:SetBackdropColor(0, 0, 0, 1)
		txtBox.__Style = TEMPLATE_LIGHT

        txtBox.OnEscapePressed = txtBox.OnEscapePressed + OnEscapePressed
        txtBox.OnEditFocusLost = txtBox.OnEditFocusLost + OnEditFocusLost
        txtBox.OnEditFocusGained = txtBox.OnEditFocusGained + OnEditFocusGained

		return txtBox
	end
endclass "SingleTextBox"