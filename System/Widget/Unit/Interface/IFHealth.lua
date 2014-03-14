-- Author      : Kurapica
-- Create Date : 2012/06/25
-- Change Log  :

-- Check Version
local version = 2
if not IGAS:NewAddon("IGAS.Widget.Unit.IFHealth", version) then
	return
end

_IFHealthUnitList = _IFHealthUnitList or UnitList(_Name)
_IFHealthUnitMaxHealthCache = _IFHealthUnitMaxHealthCache or {}
_MinMax = MinMax(0, 1)

function _IFHealthUnitList:OnUnitListChanged()
	self:RegisterEvent("UNIT_HEALTH")
	self:RegisterEvent("UNIT_MAXHEALTH")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.OnUnitListChanged = nil
end

function _IFHealthUnitList:ParseEvent(event, unit)
	if not self:HasUnit(unit) and event ~= "PLAYER_ENTERING_WORLD" then return end

	if event == "UNIT_HEALTH" then
		_MinMax.max = UnitHealthMax(unit)
		if _IFHealthUnitMaxHealthCache[unit] ~= _MinMax.max then
			_IFHealthUnitMaxHealthCache[unit] = _MinMax.max
			self:EachK(unit, "MinMaxValue", _MinMax)
		end

		if UnitIsConnected(unit) then
			self:EachK(unit, "Value", UnitHealth(unit))
		else
			self:EachK(unit, "Value", UnitHealthMax(unit))
		end
	elseif event == "UNIT_MAXHEALTH" then
		_MinMax.max = UnitHealthMax(unit)
		_IFHealthUnitMaxHealthCache[unit] = _MinMax.max

		self:EachK(unit, "MinMaxValue", _MinMax)
		self:EachK(unit, "Value", UnitHealth(unit))
	elseif event == "PLAYER_ENTERING_WORLD" then
		for unit in pairs(self) do
			self:EachK(unit, "Refresh")
		end
	end
end

__Doc__[[
	<desc>IFHealth is used to handle the unit health updating</desc>
	<optional name="MinMaxValue" type="property" valuetype="System.Widget.MinMax">used to receive the min and max value of the health</optional>
	<optional name="Value" type="property" valuetype="number">used to receive the health's value</optional>
]]
interface "IFHealth"
	extend "IFUnitElement"

	------------------------------------------------------
	-- Event
	------------------------------------------------------

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	function Refresh(self)
		if self.Unit then
			_MinMax.max = UnitHealthMax(self.Unit)
			self.MinMaxValue = _MinMax
			self.Value = UnitHealth(self.Unit)
		else
			self.Value = 0
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------

	------------------------------------------------------
	-- Event Handler
	------------------------------------------------------
	local function OnUnitChanged(self)
		_IFHealthUnitList[self] = self.Unit
	end

	------------------------------------------------------
	-- Dispose
	------------------------------------------------------
	function Dispose(self)
		_IFHealthUnitList[self] = nil
	end

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function IFHealth(self)
		self.OnUnitChanged = self.OnUnitChanged + OnUnitChanged

		-- Default Texture
		if self:IsClass(StatusBar) and not self.StatusBarTexture then
			self.StatusBarTexturePath = [[Interface\TargetingFrame\UI-StatusBar]]
			self.StatusBarColor = ColorType(0, 1, 0)
		end

		self.MouseEnabled = false
	end
endinterface "IFHealth"