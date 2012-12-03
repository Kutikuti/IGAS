-- Author      : Kurapica
-- Create Date : 2012/08/27
-- Change Log  :
--               2012/09/07 Dispose & Clear method added

-- Check Version
local version = 2
if not IGAS:NewAddon("IGAS.Widget.IFAutoPosition", version) then
	return
end

----------------------------------------------------------
-- Manage Functions
----------------------------------------------------------
do
	_Global = "Global"

	_IFAutoPosition_Loaded = _IFAutoPosition_Loaded or false
	_IFAutoPosition_LoadingList = _IFAutoPosition_LoadingList or setmetatable({}, {__mode="k"})

	_M:ActiveThread("OnLoad")

	function Init(frm, value)
		if value == 0 then return end

		local set = frm.IFAutoPositionForCharacter and _DBChar[frm:GetName()] or _DB[frm:GetName()]

		if set then
			if value >= 2 and set.Location then
				frm.Location = set.Location
			end
			if value%2 == 1 and set.Size then
				frm.Size = set.Size
			end
		end
	end

	function OnLoad(self)
		-- DB
		IGAS_DB_Char.IFAutoPosition_DB = IGAS_DB_Char.IFAutoPosition_DB or {}
		_DBChar = IGAS_DB_Char.IFAutoPosition_DB

		IGAS_DB.IFAutoPosition_DB = IGAS_DB.IFAutoPosition_DB or {}
		_DB = IGAS_DB.IFAutoPosition_DB

		if InCombatLockdown() then
			System.Threading.WaitEvent "PLAYER_REGEN_ENABLED"
		end

		local ok, ret

		for frm, value in pairs(_IFAutoPosition_LoadingList) do
			ok, ret = pcall(Init, frm, value or 0)

			if not ok then
				errorhandler(ret)
			end
		end

		wipe(_IFAutoPosition_LoadingList)
		_IFAutoPosition_LoadingList = nil

		_IFAutoPosition_Loaded = true
	end
end

-----------------------------------------------
--- IFAutoPosition
-- @type interface
-- @name IFAutoPosition
-----------------------------------------------
interface "IFAutoPosition"
	------------------------------------------------------
	-- Script
	------------------------------------------------------

	------------------------------------------------------
	-- Script Handler
	------------------------------------------------------
	local function OnPositionChanged(self)
		if not _IFAutoPosition_Loaded then return end

		if self.IFAutoPositionForCharacter then
			_DBChar[self:GetName()] = _DBChar[self:GetName()] or {}
			_DBChar[self:GetName()].Location = self.Location
		else
			_DB[self:GetName()] = _DB[self:GetName()] or {}
			_DB[self:GetName()].Location = self.Location
		end
	end

	local function OnSizeChanged(self)
		if not _IFAutoPosition_Loaded then return end

		if self.IFAutoPositionForCharacter then
			_DBChar[self:GetName()] = _DBChar[self:GetName()] or {}
			_DBChar[self:GetName()].Size = self.Size
		else
			_DB[self:GetName()] = _DB[self:GetName()] or {}
			_DB[self:GetName()].Size = self.Size
		end
	end

	------------------------------------------------------
	-- Method
	------------------------------------------------------
	------------------------------------
	--- Dispose
	-- @name Dispose
	-- @type function
	------------------------------------
	function Dispose(self)
		-- Clear save data
		if self:HasScript("OnPositionChanged") and self.IFAutoPositionAutoPosition then
			self.OnPositionChanged = self.OnPositionChanged - OnPositionChanged
		end
		if self:HasScript("OnSizeChanged") and self.IFAutoPositionAutoSize then
			self.OnSizeChanged = self.OnSizeChanged - OnSizeChanged
		end

		if _IFAutoPosition_Loaded then
			if self.IFAutoPositionForCharacter then
				_DBChar[self:GetName()] = nil
			else
				_DB[self:GetName()] = nil
			end
		end
	end

	------------------------------------
	--- Clear Position data
	-- @name ClearPosition
	-- @type function
	------------------------------------
	function ClearPosition(self)
		if self.IFAutoPositionAutoPosition then
			error("Can't clear position for auto position frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			if self.IFAutoPositionForCharacter then
				if _DBChar[self:GetName()] then
					_DBChar[self:GetName()].Location = nil

					if not next(_DBChar[self:GetName()]) then
						_DBChar[self:GetName()] = nil
					end
				end
			else
				if _DB[self:GetName()] then
					_DB[self:GetName()].Location = nil

					if not next(_DB[self:GetName()]) then
						_DB[self:GetName()] = nil
					end
				end
			end
		end
	end

	------------------------------------
	--- Clear Size data
	-- @name ClearSize
	-- @type function
	------------------------------------
	function ClearSize(self)
		if self.IFAutoPositionAutoSize then
			error("Can't clear size for auto size frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			if self.IFAutoPositionForCharacter then
				if _DBChar[self:GetName()] then
					_DBChar[self:GetName()].Size = nil

					if not next(_DBChar[self:GetName()]) then
						_DBChar[self:GetName()] = nil
					end
				end
			else
				if _DB[self:GetName()] then
					_DB[self:GetName()].Size = nil

					if not next(_DB[self:GetName()]) then
						_DB[self:GetName()] = nil
					end
				end
			end
		end
	end
	------------------------------------
	--- Load Position from db
	-- @name LoadPosition
	-- @type function
	------------------------------------
	function LoadPosition(self)
		if self.IFAutoPositionAutoPosition then
			error("Can't load position for auto position frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			local set = self.IFAutoPositionForCharacter and _DBChar[self:GetName()] or _DB[self:GetName()]

			if set then
				if set.Location then
					self.Location = set.Location
				end
			end
		else
			_IFAutoPosition_LoadingList[self] = _IFAutoPosition_LoadingList[self] or 0 + 2
		end
	end

	------------------------------------
	--- Load Size from db
	-- @name LoadSize
	-- @type function
	------------------------------------
	function LoadSize(self)
		if self.IFAutoPositionAutoSize then
			error("Can't load size for auto size frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			local set = self.IFAutoPositionForCharacter and _DBChar[self:GetName()] or _DB[self:GetName()]

			if set then
				if set.Size then
					self.Size = set.Size
				end
			end
		else
			_IFAutoPosition_LoadingList[self] = _IFAutoPosition_LoadingList[self] or 0 + 1
		end
	end

	------------------------------------
	--- Save position to db
	-- @name SavePosition
	-- @type function
	------------------------------------
	function SavePosition(self)
		if self.IFAutoPositionAutoPosition then
			error("Can't save position for auto position frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			if self.IFAutoPositionForCharacter then
				_DBChar[self:GetName()] = _DBChar[self:GetName()] or {}
				_DBChar[self:GetName()].Location = self.Location
			else
				_DB[self:GetName()] = _DB[self:GetName()] or {}
				_DB[self:GetName()].Location = self.Location
			end
		end
	end

	------------------------------------
	--- Save size to db
	-- @name SaveSize
	-- @type function
	------------------------------------
	function SaveSize(self)
		if self.IFAutoPositionAutoSize then
			error("Can't save size for auto size frame.", 2)
		end

		if _IFAutoPosition_Loaded then
			if self.IFAutoPositionForCharacter then
				_DBChar[self:GetName()] = _DBChar[self:GetName()] or {}
				_DBChar[self:GetName()].Size = self.Size
			else
				_DB[self:GetName()] = _DB[self:GetName()] or {}
				_DB[self:GetName()].Size = self.Size
			end
		end
	end

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	-- IFAutoPositionForCharacter
	property "IFAutoPositionForCharacter" {
		Get = function(self)
			return true
		end,
	}
	-- IFAutoPositionAutoSize
	property "IFAutoPositionAutoSize" {
		Get = function(self)
			return true
		end,
	}
	-- IFAutoPositionAutoPosition
	property "IFAutoPositionAutoPosition" {
		Get = function(self)
			return true
		end,
	}

	------------------------------------------------------
	-- Initialize
	------------------------------------------------------
    function IFAutoPosition(self)
		if Reflector.ObjectIsClass(self, Region) then
			if _IFAutoPosition_Loaded then
				local set = self.IFAutoPositionForCharacter and _DBChar[self:GetName()] or _DB[self:GetName()]

				if set then
					if self.IFAutoPositionAutoPosition and set.Location then
						self.Location = set.Location
					end
					if self.IFAutoPositionAutoSize and set.Size then
						self.Size = set.Size
					end
				end
			else
				_IFAutoPosition_LoadingList[self] = 0 + (self.IFAutoPositionAutoSize and 1 or 0) + (self.IFAutoPositionAutoPosition and 2 or 0)
			end

			if self:HasScript("OnPositionChanged") and self.IFAutoPositionAutoPosition then
				self.OnPositionChanged = self.OnPositionChanged + OnPositionChanged
			end
			if self:HasScript("OnSizeChanged") and self.IFAutoPositionAutoSize then
				self.OnSizeChanged = self.OnSizeChanged + OnSizeChanged
			end
		end
    end
endinterface "IFAutoPosition"