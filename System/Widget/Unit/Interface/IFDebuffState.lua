-- Author      : Kurapica
-- Create Date : 2012/11/09
-- Change Log  :

----------------------------------------------------------------------------------------------------------------------------------------
--- IFDebuffState
-- @type Interface
-- @name IFDebuffState
-- @need script : OnStateChanged
----------------------------------------------------------------------------------------------------------------------------------------

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Unit.IFDebuffState", version) then
	return
end

_IFDebuffStateUnitList = _IFDebuffStateUnitList or UnitList(_Name)

_IFDebuffStateCache = _IFDebuffStateCache or {
	Magic = {},
	Curse = {},
	Disease = {},
	Poison = {},
}

function _IFDebuffStateUnitList:OnUnitListChanged()
	self:RegisterEvent("UNIT_AURA")

	self.OnUnitListChanged = nil
end

function _IFDebuffStateUnitList:ParseEvent(event, unit)
	if not _IFDebuffStateUnitList:HasUnit(unit) then
		return
	end

	if event == "UNIT_AURA" then
		return UpdateAuraState(unit)
	end
end

function UpdateAuraState(unit)
	local index = 1
	local name, _, dtype
	local hasMagic, hasCurse, hasDisease, hasPoison = false, false, false, false
	local changed = false

	while true do
		name, _, _, _, dtype = UnitAura(unit, index, "HARMFUL")

		if name then
			if dtype == "Magic" then
				hasMagic = true
			elseif dtype == "Curse" then
				hasCurse = true
			elseif dtype == "Disease" then
				hasDisease = true
			elseif dtype == "Poison" then
				hasPoison = true
			end
		else
			break
		end

		index = index + 1
	end

	if _IFDebuffStateCache.Magic[unit] ~= hasMagic then
		changed = true
		_IFDebuffStateCache.Magic[unit] = hasMagic
		_IFDebuffStateUnitList:EachK(unit, "HasMagic", hasMagic)
	end

	if _IFDebuffStateCache.Curse[unit] ~= hasCurse then
		changed = true
		_IFDebuffStateCache.Curse[unit] = hasCurse
		_IFDebuffStateUnitList:EachK(unit, "HasCurse", hasCurse)
	end

	if _IFDebuffStateCache.Disease[unit] ~= hasDisease then
		changed = true
		_IFDebuffStateCache.Disease[unit] = hasDisease
		_IFDebuffStateUnitList:EachK(unit, "HasDisease", hasDisease)
	end

	if _IFDebuffStateCache.Poison[unit] ~= hasPoison then
		changed = true
		_IFDebuffStateCache.Poison[unit] = hasPoison
		_IFDebuffStateUnitList:EachK(unit, "HasPoison", hasPoison)
	end

	if changed then
		for ele in _IFDebuffStateUnitList(unit) do
			Object.Fire(ele, "OnStateChanged")
		end
	end
end

interface "IFDebuffState"
	extend "IFUnitElement"

	------------------------------------------------------
	-- Script
	------------------------------------------------------
	script "OnStateChanged"

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	function Dispose(self)
		_IFDebuffStateUnitList[self] = nil
	end

	------------------------------------
	--- Refresh the element
	-- @name Refresh
	-- @type function
	------------------------------------
	function Refresh(self)
		if self.Unit then
			UpdateAuraState(self.Unit)
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------

	------------------------------------------------------
	-- Script Handler
	------------------------------------------------------
	local function OnUnitChanged(self)
		_IFDebuffStateUnitList[self] = self.Unit
	end

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function IFDebuffState(self)
		self.OnUnitChanged = self.OnUnitChanged + OnUnitChanged
	end
endinterface "IFDebuffState"