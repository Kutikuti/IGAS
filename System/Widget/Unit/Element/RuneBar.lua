﻿-- Author      : Kurapica
-- Create Date : 2012/07/18
-- Change Log  :

----------------------------------------------------------------------------------------------------------------------------------------
--- RuneBar
-- <br><br>inherit <a href="..\Common\LayoutPanel.html">LayoutPanel</a> For all methods, properties and scriptTypes
-- @name RuneBar
----------------------------------------------------------------------------------------------------------------------------------------

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Unit.RuneBar", version) then
	return
end

class "RuneBar"
	inherit "LayoutPanel"
	extend "IFRune"

	GameTooltip = _G.GameTooltip
	RUNES_TOOLTIP = _G.RUNES_TOOLTIP

	MAX_RUNES = 6

	RUNETYPE_COMMON = 0
	RUNETYPE_BLOOD = 1
	RUNETYPE_UNHOLY = 2
	RUNETYPE_FROST = 3
	RUNETYPE_DEATH = 4

	IconTextures = {
		[RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
		[RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
		[RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
		[RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
	}

	RuneTextures = {
		[RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Blood-Off.tga",
		[RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Death-Off.tga",
		[RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Frost-Off.tga",
		[RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Chromatic-Off.tga",
	}

	RuneEnergizeTextures = {
		[RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\Deathknight-Energize-Blood",
		[RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\Deathknight-Energize-Unholy",
		[RUNETYPE_FROST] = "Interface\\PlayerFrame\\Deathknight-Energize-Frost",
		[RUNETYPE_DEATH] = "Interface\\PlayerFrame\\Deathknight-Energize-White",
	}

	RuneColors = {
		[RUNETYPE_COMMON] = ColorType(1, 1, 1),
		[RUNETYPE_BLOOD] = ColorType(1, 0, 0),
		[RUNETYPE_UNHOLY] = ColorType(0, 0.5, 0),
		[RUNETYPE_FROST] = ColorType(0, 1, 1),
		[RUNETYPE_DEATH] = ColorType(0.8, 0.1, 1),
	}

	RuneMapping = {
		[1] = "BLOOD",
		[2] = "UNHOLY",
		[3] = "FROST",
		[4] = "DEATH",
	}

	RuneBtnMapping = {
		[1] = 1,
		[2] = 2,
		[3] = 5,
		[4] = 6,
		[5] = 3,
		[6] = 4,
	}

	class "RuneButton"
		inherit "Button"
		extend "IFCooldownIndicator"

		ALPHA_PER = 0.2

		------------------------------------------------------
		-- Script
		------------------------------------------------------

		------------------------------------------------------
		-- Method
		------------------------------------------------------
		------------------------------------
		--- Custom the indicator
		-- @name SetUpCooldownIndicator
		-- @class function
		-- @param indicator the cooldown object
		------------------------------------
		function SetUpCooldownIndicator(self, indicator)
			indicator.FrameStrata = "LOW"
			indicator:SetPoint("TOPLEFT", 2, -2)
			indicator:SetPoint("BOTTOMRIGHT", -1, 1)
		end

		------------------------------------
		--- Update cooldown by index
		-- @name UpdatePower
		-- @class function
		------------------------------------
		function UpdatePower(self, isEnergize)
			if not self.ID then return end

			local start, duration, runeReady = GetRuneCooldown(self.ID)

			if not runeReady then
				if start then
					self.Cooldown:SetCooldown(start, duration)
					self.Cooldown.Visible = true
				end
				self:Stop();
			else
				self.Cooldown:Hide();
				self.Shine.Texture.VertexColor = RuneColors[RUNETYPE_COMMON]
				self:StartShine()
			end

			if isEnergize then
				self:Play()
			end
		end

		------------------------------------------------------
		-- Property
		------------------------------------------------------
		-- RuneType
		property "RuneType" {
			Get = function(self)
				return self.__RuneType
			end,
			Set = function(self, value)
				if self.RuneType ~= value then
					self.__RuneType = value
					self.Glow.RuneColorGlow.TexturePath = RuneEnergizeTextures[value]

					if value then
						self.Rune.TexturePath = IconTextures[value]

						self.Rune.Visible = true

						self.Tooltip = _G["COMBAT_TEXT_RUNE_"..RUNE_MAPPING[value]]

						self.Shine.Texture.VertexColor = RuneColors[value]
						self.Shine.Texture.Energize.Playing = true
					else
						self.Rune.Visible = false
						self.Tooltip = nil
					end
				end
			end,
			Type = System.Number + nil,
		}
		-- Ready
		property "Ready" {
			Get = function(self)
				return self.__Ready
			end,
			Set = function(self, value)
				if self.Ready ~= value then
					self.__Ready = value

					if value then
						self.Shine.Texture.VertexColor = RuneColors[0]
						self.Shine.Texture.Energize.Playing = true
					else
						self.Glow.RuneWhiteGlow.Energize:Stop()
						self.Glow.RuneColorGlow.Energize:Stop()
					end
				end
			end,
			Type = System.Boolean,
		}
		-- Energize
		property "Energize" {
			Get = function(self)
				return self.__Energize
			end,
			Set = function(self, value)
				if self.Energize ~= value then
					self.__Energize = value

					if value then
						self.Glow.RuneWhiteGlow.Energize:Play()
						self.Glow.RuneColorGlow.Energize:Play()
					else
						self.Glow.RuneWhiteGlow.Energize:Stop()
						self.Glow.RuneColorGlow.Energize:Stop()
					end
				end
			end,
			Type = System.Boolean,
		}

		------------------------------------------------------
		-- Script Handler
		------------------------------------------------------
		local function OnEnter(self)
			if self.Tooltip then
				GameTooltip_SetDefaultAnchor(GameTooltip, IGAS:GetUI(self))
				GameTooltip:SetText(self.Tooltip, 1, 1, 1)
				GameTooltip:AddLine(RUNES_TOOLTIP, nil, nil, nil, true)
				GameTooltip:Show()
			end
		end

		local function OnLeave(self)
			GameTooltip:Hide()
		end

		local function Shine_OnFinished(self)
			self.Parent.Alpha = 0
		end

		------------------------------------------------------
		-- Constructor
		------------------------------------------------------
		function RuneButton(name, parent)
			local btn = Super(name, parent)

			btn.Height = 18
			btn.Width = 18

			-- Border
			local border = Frame("Border", btn)
			border.FrameStrata = "LOW"
			border:SetPoint("TOPLEFT", -3, 3)
			border:SetPoint("BOTTOMRIGHT", 3, -3)

			local borderTexture = Texture("Texture", border, "OVERLAY")
			borderTexture.TexturePath = [[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Ring]]
			borderTexture.VertexColor = ColorType(0.6, 0.6, 0.6, 1)
			borderTexture:SetAllPoints(border)

			border.FrameLevel = border.FrameLevel + 1

			-- Shine
			local shine = Frame("Shine", btn)
			shine.FrameStrata = "MEDIUM"
			shine:SetAllPoints(btn)

			local shineTexture = Texture("Texture", shine, "OVERLAY")
			shineTexture.TexturePath = [[Interface\ComboFrame\ComboPoint]]
			shineTexture.BlendMode = "ADD"
			shineTexture.Alpha = 0
			shineTexture:SetPoint("TOPLEFT", -21, 9)
			shineTexture:SetPoint("BOTTOMRIGHT", 21, -9)
			shineTexture:SetTexCoord(0.5625, 1, 0, 1)

			-- Glow
			local glow = Frame("Glow", btn)
			glow.FrameStrata = "HIGH"
			glow:SetAllPoints(btn)

			local glowWhite = Texture("RuneWhiteGlow", glow, "OVERLAY", nil, -1)
			glowWhite.TexturePath = [[Interface\PlayerFrame\Deathknight-Energize-White]]
			glowWhite.Alpha = 0
			glowWhite:SetPoint("TOPLEFT", 5, -5)
			glowWhite:SetPoint("BOTTOMRIGHT", -5, 5)

			local glowColor = Texture("RuneColorGlow", glow, "OVERLAY")
			glowColor.TexturePath = [[Interface\PlayerFrame\Deathknight-Energize-Blood]]
			glowColor.Alpha = 0
			glowColor:SetPoint("TOPLEFT", -7, 7)
			glowColor:SetPoint("BOTTOMRIGHT", 7, -7)

			-- RuneTexture
			local rune = Texture("Rune", btn, "ARTWORK")
			rune.TexturePath = [[Interface\PlayerFrame\UI-PlayerFrame-Deathknight-Blood]]
			rune:SetPoint("TOPLEFT", -3, 3)
			rune:SetPoint("BOTTOMRIGHT", 3, -3)

			-- Animation for RuneWhiteGlow
			local energize = AnimationGroup("Energize", glowWhite)

			local scale = Scale("Scale", energize)
			scale.Order = 1
			scale.Duration = 0.15
			scale.EndDelay = 1
			scale.Scale = Dimension(4, 4)

			local alpha = Alpha("Alpha1", energize)
			alpha.Order = 1
			alpha.Duration = 0.2
			alpha.EndDelay = 1
			alpha.Change = 1

			alpha = Alpha("Alpha2", energize)
			alpha.Order = 2
			alpha.Duration = 0.1
			alpha.Smoothing = "IN_OUT"
			alpha.Change = -1

			-- Animation for RuneColorGlow
			energize = AnimationGroup("Energize", glowColor)

			alpha = Alpha("Alpha1", energize)
			alpha.Order = 1
			alpha.Duration = 0.1
			alpha.StartDelay = 0.3
			alpha.EndDelay = 4
			alpha.Smoothing = "IN_OUT"
			alpha.Change = 1

			alpha = Alpha("Alpha2", energize)
			alpha.Order = 2
			alpha.Duration = 0.1
			alpha.Smoothing = "IN_OUT"
			alpha.Change = -1

			energize = AnimationGroup("Energize", shineTexture)

			energize.OnFinished = Shine_OnFinished

			alpha = Alpha("Alpha1", energize)
			alpha.Duration = 0.5
			alpha.Order = 1
			alpha.Change = 1

			alpha = Alpha("Alpha2", energize)
			alpha.Duration = 0.5
			alpha.Order = 2
			alpha.Change = -1

			btn.OnEnter = btn.OnEnter + OnEnter
			btn.OnLeave = btn.OnLeave + OnLeave

			return btn
		end
	endclass "RuneButton"

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function RuneBar(name, parent)
		local panel = Super(name, parent)
		local pct = floor(100 / MAX_RUNES)
		local margin = (100 - pct * MAX_RUNES + 3) / 2

		panel.FrameStrata = "LOW"
		panel.Toplevel = true
		panel.Width = 130
		panel.Height = 18

		local btnRune, pos

		for i = 1, MAX_RUNES do
			btnRune = RuneButton("Individual"..i, panel)
			btnRune.ID = i

			panel:AddWidget(btnRune)

			pos = RuneBtnMapping[i]

			panel:SetWidgetLeftWidth(btnRune, margin + (pos-1)*pct, "pct", pct-3, "pct")

			panel[i] = btnRune
		end

		return panel
	end
endclass "RuneBar"