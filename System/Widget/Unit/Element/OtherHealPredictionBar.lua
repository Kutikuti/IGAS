-- Author      : Kurapica
-- Create Date : 2013/09/12
-- Change Log  :

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Unit.OtherHealPredictionBar", version) then
	return
end

class "OtherHealPredictionBar"
	inherit "StatusBar"
	extend "IFOtherHealPrediction"

	doc [======[
		@name OtherHealPredictionBar
		@type class
		@desc The prediction heal of the other players
	]======]

	_OtherHealPredictionBarMap = _OtherHealPredictionBarMap or setmetatable({}, {__mode = "kv"})

	------------------------------------------------------
	-- Script Handler
	------------------------------------------------------
	local function OnSizeChanged(self)
		if _OtherHealPredictionBarMap[self] then
			_OtherHealPredictionBarMap[self].Size = self.Size
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	doc [======[
		@name HealthBar
		@type property
		@desc The target health bar the prediction bar should attach to
	]======]
	property "HealthBar" {
		Field = "__HealthBar",
		Set = function(self, value)
			if self.__HealthBar ~= value then
				if self.__HealthBar then
					self.__HealthBar.OnSizeChanged = self.__HealthBar.OnSizeChanged - OnSizeChanged
					_OtherHealPredictionBarMap[self.__HealthBar] = nil
				end

				self.__HealthBar = value
				_OtherHealPredictionBarMap[value] = self

				self:ClearAllPoints()
				self:SetPoint("TOPLEFT", value.StatusBarTexture, "TOPRIGHT")
				self.FrameLevel = value.FrameLevel + 2
				self.Size = value.Size

				value.OnSizeChanged = value.OnSizeChanged + OnSizeChanged
			end
		end,
		Type = StatusBar,
	}

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
    function OtherHealPredictionBar(self)
		self.StatusBarTexturePath = [[Interface\Tooltips\UI-Tooltip-Background]]
		self.StatusBarColor = ColorType(0, 0.631, 0.557)
    end
endclass "OtherHealPredictionBar"