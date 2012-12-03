﻿-- Author      : Kurapica
-- Create Date : 2012/07/22
-- Change Log  :

----------------------------------------------------------------------------------------------------------------------------------------
--- MonkPowerBar
-- @type Class
-- @name MonkPowerBar
----------------------------------------------------------------------------------------------------------------------------------------

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Unit.MonkPowerBar", version) then
	return
end

class "MonkPowerBar"
	inherit "Frame"
	extend "IFClassPower"

	GameTooltip = _G.GameTooltip
	CHI_POWER = _G.CHI_POWER
	CHI_TOOLTIP = _G.CHI_TOOLTIP

	-----------------------------------------------
	--- LightEnergy
	-- @type class
	-- @name LightEnergy
	-----------------------------------------------
	class "LightEnergy"
		inherit "Frame"

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		-- Activated
		property "Activated" {
			Get = function(self)
				return self.__Activated or false
			end,
			Set = function(self, value)
				if self.Activated ~= value then
					self.__Activated = value

					if value then
						self.Glow.Deactivate.Playing = false
						self.Glow.Active.Playing = true
					else
						self.Glow.Active.Playing = false
						self.Glow.Deactivate.Playing = true
					end
				end
			end,
			Type = System.Boolean,
		}

		------------------------------------------------------
		-- Script Handler
		------------------------------------------------------
		local function Active_OnFinished(self)
			self.Parent.Alpha = 1
		end

		local function Deactivate_OnFinished(self)
			self.Parent.Alpha = 0
		end

		local function OnEnter(self)
			GameTooltip_SetDefaultAnchor(GameTooltip, IGAS:GetUI(self))
			GameTooltip:SetText(CHI_POWER, 1, 1, 1)
			GameTooltip:AddLine(CHI_TOOLTIP, nil, nil, nil, true)
			GameTooltip:Show()
		end

		local function OnLeave(self)
			GameTooltip:Hide()
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
	    function LightEnergy(...)
			local lightEnergy = Super(...)
			lightEnergy:SetSize(18, 17)

			-- BACKGROUND
			local bg = Texture("Bg", lightEnergy, "BACKGROUND")
			bg.TexturePath = [[Interface\PlayerFrame\MonkUI]]
			bg:SetTexCoord(0.09375000, 0.17578125, 0.71093750, 0.87500000)
			bg:SetSize(21, 21)
			bg:SetPoint("CENTER")

			-- ARTWORK
			local glow = Texture("Glow", lightEnergy, "ARTWORK")
			glow.Alpha = 0
			glow.TexturePath = [[Interface\PlayerFrame\MonkUI]]
			glow:SetTexCoord(0.00390625, 0.08593750, 0.71093750, 0.87500000)
			glow:SetSize(21, 21)
			glow:SetPoint("CENTER")

			-- Animation
			local active = AnimationGroup("Active", glow)
			local alpha = Alpha("Alpha", active)
			alpha.Duration = 0.2
			alpha.Order = 1
			alpha.Change = 1

			active.OnFinished = Active_OnFinished

			local deactivate = AnimationGroup("Deactivate", glow)
			alpha = Alpha("Alpha", deactivate)
			alpha.Duration = 0.3
			alpha.Order = 1
			alpha.Change = -1

			deactivate.OnFinished = Deactivate_OnFinished

			lightEnergy.OnEnter = lightEnergy.OnEnter + OnEnter
			lightEnergy.OnLeave = lightEnergy.OnLeave + OnLeave

			return lightEnergy
	    end
	endclass "LightEnergy"

	------------------------------------------------------
	-- Property
	------------------------------------------------------
	-- MinMaxValue
	property "MinMaxValue" {
		Get = function(self)
			return MinMax(self.__Min, self.__Max)
		end,
		Set = function(self, value)
			if self.__Max ~= value.max then
				self.LightEnergy1:SetPoint("LEFT", (self.Width - self.LightEnergy1.Width * value.max - 5 * (value.max-1)) / 2, 1)

				if value.max == 4 then
					self.LightEnergy5.Visible = false
				else
					self.LightEnergy5.Visible = true
				end
			end
			self.__Min, self.__Max = value.min, value.max
		end,
		Type = System.MinMax,
	}
	-- Value
	property "Value" {
		Get = function(self)
			return self.__Value
		end,
		Set = function(self, value)
			if self.__Value ~= value then
				for  i = 1, self.__Max do
					self["LightEnergy"..i].Activated = i <= value
				end

				self.__Value = value
			end
		end,
		Type = System.Number,
	}

	------------------------------------------------------
	-- Script Handler
	------------------------------------------------------

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function MonkPowerBar(name, parent)
		local panel = Super(name, parent)

		panel.__Value = 0
		panel.__Min, panel.__Max = 0, 0

		panel.FrameStrata = "LOW"
		panel.Toplevel = true
		panel:SetSize(136, 60)
		panel.MouseEnabled = true

		-- BACKGROUND
		local bgShadow = Texture("BgShadow", panel, "BACKGROUND")
		bgShadow.TexturePath = [[Interface\PlayerFrame\MonkUI]]
		bgShadow:SetTexCoord(0.00390625, 0.53515625, 0.00781250, 0.34375000)
		bgShadow:SetAllPoints()

		-- BORDER
		local bg = Texture("Bg", panel, "BORDER")
		bg.TexturePath = [[Interface\PlayerFrame\MonkUI]]
		bg:SetTexCoord(0.00390625, 0.53515625, 0.35937500, 0.69531250)
		bg:SetAllPoints()

		-- LightEnergy
		local prev

		for i = 1, 5 do
			local light = LightEnergy("LightEnergy"..i, panel)

			if i == 1 then
				light:SetPoint("LEFT", (panel.Width - light.Width * 4 - 5 * 3) / 2, 1)
			else
				light:SetPoint("LEFT", prev, "RIGHT", 5, 0)
			end

			prev = light
		end

		return panel
	end
endclass "MonkPowerBar"