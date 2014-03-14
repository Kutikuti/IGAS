-- Author      : Kurapica
-- Create Date : 2012/06/25
-- Change Log  :

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Unit.IFUnitLevel", version) then
	return
end

_IFUnitLevelUnitList = _IFUnitLevelUnitList or UnitList(_Name)

_All = "all"

function _IFUnitLevelUnitList:OnUnitListChanged()
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	self.OnUnitListChanged = nil
end

function _IFUnitLevelUnitList:ParseEvent(event, level)
	self:EachK(_All, "Refresh", event == "PLAYER_LEVEL_UP" and level or nil)
end

__Doc__[[
	<desc>IFUnitLevel is used to handle the unit level's update</desc>
	<optional name="Value" type="property" valuetype="number">which used to receive the unit's level</optional>
]]
interface "IFUnitLevel"
	extend "IFUnitElement"

	------------------------------------------------------
	-- Event
	------------------------------------------------------

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	function Refresh(self, playerLevel)
		if self.Unit then
			local lvl = UnitLevel(self.Unit)

			if self.Unit == "player" and playerLevel then
				lvl = playerLevel
			end

			self.Value = lvl
		else
			self.Value = nil
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------

	------------------------------------------------------
	-- Event Handler
	------------------------------------------------------

	------------------------------------------------------
	-- Dispose
	------------------------------------------------------
	function Dispose(self)
		_IFUnitLevelUnitList[self] = nil
	end

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function IFUnitLevel(self)
		_IFUnitLevelUnitList[self] = _All
	end
endinterface "IFUnitLevel"