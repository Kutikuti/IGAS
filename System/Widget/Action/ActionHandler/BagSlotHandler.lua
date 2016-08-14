-- Author      : Kurapica
-- Create Date : 2013/11/25
-- Change Log  :

-- Check Version
local version = 1
if not IGAS:NewAddon("IGAS.Widget.Action.BagSlotHandler", version) then
	return
end

import "System.Widget.Action.ActionRefreshMode"

_Enabled = false
_BagCache = {}

LE_ITEM_QUALITY_POOR = _G.LE_ITEM_QUALITY_POOR
REPAIR_COST = _G.REPAIR_COST

-- Event handler
function OnEnable(self)
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("INVENTORY_SEARCH_UPDATE")
	self:RegisterEvent("BAG_NEW_ITEMS_UPDATED")

	self:RegisterEvent("MERCHANT_SHOW")
	self:RegisterEvent("MERCHANT_CLOSED")

	OnEnable = nil

	return handler:Refresh()
end

function QUEST_ACCEPTED(self)
	return handler:Refresh()
end

function UNIT_QUEST_LOG_CHANGED(self, unit)
	if unit ~= "player" then return end
	return handler:Refresh()
end

function BAG_UPDATE(self, bag)
	if _BagCache[bag] then
		for btn in pairs(_BagCache[bag]) do
			handler:Refresh(btn)
		end
	end
end

function ITEM_LOCK_CHANGED(self, bag, slot)
	if _BagCache[bag] and slot then
		local _, _, locked = GetContainerItemInfo(bag, slot)

		for btn, bslot in pairs(_BagCache[bag]) do
			if bslot == slot then
				btn.IconLocked = locked
			end
		end
	end
end

function BAG_UPDATE_COOLDOWN(self)
	return handler:Refresh(RefreshCooldown)
end

function INVENTORY_SEARCH_UPDATE(self)
	for bag, cache in pairs(_BagCache) do
		for btn, slot in pairs(cache) do
			btn.ShowSearchOverlay = select(8, GetContainerItemInfo(bag, slot))
		end
	end
end

function BAG_NEW_ITEMS_UPDATED(self)
	return handler:Refresh()
end

function MERCHANT_SHOW(self)
	for _, btn in handler() do
		local texture, itemCount, locked, quality, readable, _, _, isFiltered, noValue, itemID = GetContainerItemInfo(btn.ActionTarget, btn.ActionDetail)

		if itemID then
			self.ShowJunkIcon = (quality == LE_ITEM_QUALITY_POOR and not noValue)
		else
			self.ShowJunkIcon = false
		end
	end
end

function MERCHANT_CLOSED(self)
	for _, btn in handler() do
		btn.ShowJunkIcon = false
	end
end

----------------------------------------
-- BagSlot Handler
----------------------------------------
handler = ActionTypeHandler {
	Name = "bagslot",
	Target = "bag",
	Detail = "slot",

	DragStyle = "Keep",
	ReceiveStyle = "Keep",

	UpdateSnippet = [[
		self:SetAttribute("*type1", "macro")
		self:SetAttribute("*type2", "macro")
		self:SetAttribute("*macrotext1", "/click IGAS_BagSlot_FakeItemButton LeftButton")
		self:SetAttribute("*macrotext2", "/click IGAS_BagSlot_FakeItemButton RightButton")
		Manager:CallMethod("RegisterBagSlot", self:GetName())
	]],
	ClearSnippet = [[
		self:SetAttribute("*type1", nil)
		self:SetAttribute("*type2", nil)
		self:SetAttribute("*macrotext1", nil)
		self:SetAttribute("*macrotext2", nil)
		Manager:CallMethod("UnregisterBagSlot", self:GetName())
	]],
	ReceiveSnippet = "Custom",

	PreClickSnippet = [[
		local bag = self:GetAttribute("bag")
		local slot = self:GetAttribute("slot")

		_BagSlot_FakeContainer:SetID(bag)
		_BagSlot_FakeItemButton:SetID(slot)

		_BagSlot_FakeItemButton:ClearAllPoints()
		_BagSlot_FakeItemButton:SetPoint("TOPRIGHT", self, "TOPRIGHT")
	]],

	OnEnableChanged = function(self) _Enabled = self.Enabled end,
}

-- Use fake container and item button to handle the click of item buttons
local fakeContainerFrame = CreateFrame("Frame", "IGAS_BagSlot_FakeContainer", _G.UIParent, "SecureFrameTemplate")
fakeContainerFrame:Hide()
local fakeItemButton = CreateFrame("Button", "IGAS_BagSlot_FakeItemButton", fakeContainerFrame, "ContainerFrameItemButtonTemplate, SecureFrameTemplate")
fakeItemButton:Hide()

handler.Manager:SetFrameRef("BagSlot_FakeContainer", fakeContainerFrame)
handler.Manager:SetFrameRef("BagSlot_FakeItemButton", fakeItemButton)
handler.Manager:Execute[[
	_BagSlot_FakeContainer = Manager:GetFrameRef("BagSlot_FakeContainer")
	_BagSlot_FakeItemButton = Manager:GetFrameRef("BagSlot_FakeItemButton")
]]

local function OnEnter(self)
	if self.IsNewItem then
		local bag, slot = self.ActionTarget, self.ActionDetail
		if bag and slot then
			C_NewItems.RemoveNewItem(bag, slot)

			for btn, bslot in pairs(_BagCache[bag]) do
				if bslot == slot then
					btn.IsNewItem = false
				end
			end
		end
	end

	if _G.ArtifactFrame and self._BagSlot_ItemID then
		_G.ArtifactFrame:OnInventoryItemMouseEnter(self.ActionTarget, self.ActionDetail)
	end
end

local function OnLeave(self)
	ResetCursor()

	if _G.ArtifactFrame then
		_G.ArtifactFrame:OnInventoryItemMouseLeave(self:GetParent():GetID(), self:GetID())
	end
end

IGAS:GetUI(handler.Manager).RegisterBagSlot = function (self, btnName)
	self = IGAS:GetWrapper(_G[btnName])

	local bag = self.ItemBag
	_BagCache[bag] = _BagCache[bag] or {}
	_BagCache[bag][self] = self.ItemSlot

	self.OnEnter = self.OnEnter + OnEnter
	self.OnLeave = self.OnLeave + OnLeave
end

IGAS:GetUI(handler.Manager).UnregisterBagSlot = function (self, btnName)
	self = IGAS:GetWrapper(_G[btnName])

	for k, v in pairs(_BagCache) do
		if v[self] then v[self] = nil end
	end

	self.ItemQuality = nil
	self.IconLocked = false
	self.ShowSearchOverlay = false
	self.ItemQuestStatus = nil
	self.ShowJunkIcon = false
	self.IsBattlePayItem = false
	self.IsNewItem = false

	self.OnEnter = self.OnEnter - OnEnter
	self.OnLeave = self.OnLeave - OnLeave
end

-- Overwrite methods
function handler:RefreshButton()
	local bag, slot = self.ActionTarget, self.ActionDetail

	if not bag or not slot then return end

	local texture, itemCount, locked, quality, readable, _, _, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
	local isQuestItem, questId, isActive = GetContainerItemQuestInfo(bag, slot)

	if itemID then
		self._BagSlot_ItemID = itemID
		self._BagSlot_Readable = readable
		self.ItemQuality = quality
		self.IconLocked = locked
		self.ShowSearchOverlay = isFiltered

		if questId and not isActive then
			self.ItemQuestStatus = false
		elseif questId or isQuestItem then
			self.ItemQuestStatus = true
		else
			self.ItemQuestStatus = nil
		end

		if MerchantFrame:IsShown() then
			self.ShowJunkIcon = (quality == LE_ITEM_QUALITY_POOR and not noValue)
		else
			self.ShowJunkIcon = false
		end

		self.IsBattlePayItem = IsBattlePayItem(bag, slot)
		self.IsNewItem = C_NewItems.IsNewItem(bag, slot)
	else
		self._BagSlot_ItemID = nil
		self._BagSlot_Readable = nil
		self.ItemQuality = nil
		self.IconLocked = false
		self.ShowSearchOverlay = false
		self.ItemQuestStatus = nil
		self.ShowJunkIcon = false
		self.IsBattlePayItem = false
		self.IsNewItem = false
	end
end

function handler:ReceiveAction(target, detail)
	return PickupContainerItem(target, detail)
end

function handler:HasAction()
	return true
end

function handler:GetActionTexture()
	local bag = self.ActionTarget
	local slot = self.ActionDetail

	return (GetContainerItemInfo(bag, slot))
end

function handler:GetActionCount()
	local bag = self.ActionTarget
	local slot = self.ActionDetail

	return (select(2, GetContainerItemInfo(bag, slot)))
end

function handler:GetActionCooldown()
	local bag = self.ActionTarget
	local slot = self.ActionDetail

	return GetContainerItemCooldown(bag, slot)
end

function handler:IsEquippedItem()
	return false
end

function handler:IsActivedAction()
	return false
end

function handler:IsUsableAction()
	local item = GetContainerItemID(self.ActionTarget, self.ActionDetail)

	return item and IsUsableItem(item)
end

function handler:IsConsumableAction()
	local item = GetContainerItemID(self.ActionTarget, self.ActionDetail)
	if not item then return false end

	local maxStack = select(8, GetItemInfo(item)) or 0
	return maxStack > 1
end

function handler:IsInRange()
	return IsItemInRange(GetContainerItemID(self.ActionTarget, self.ActionDetail), self:GetAttribute("unit"))
end

function handler:SetTooltip(GameTooltip)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")

	local showSell = nil
	local hasCooldown, repairCost, speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetBagItem(self.ActionTarget, self.ActionDetail)

	GameTooltip:ClearAllPoints()
	if self:GetRight() < GetScreenWidth() / 2 then
		GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT")
	else
		GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
	end

	if speciesID and speciesID > 0 then
		BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name)
		return
	else
		if _G.BattlePetTooltip then
			_G.BattlePetTooltip:Hide()
		end
	end

	if InRepairMode() and (repairCost and repairCost > 0) then
		GameTooltip:AddLine(REPAIR_COST, nil, nil, nil, true)
		SetTooltipMoney(IGAS:GetUI(GameTooltip), repairCost)
	elseif _G.MerchantFrame:IsShown() and _G.MerchantFrame.selectedTab == 1 then
		showSell = 1
	end

	if IsModifiedClick("DRESSUP") and self._BagSlot_ItemID then
		ShowInspectCursor()
	elseif showSell then
		ShowContainerSellCursor(self.ActionTarget, self.ActionDetail)
	elseif self._BagSlot_Readable then
		ShowInspectCursor()
	else
		ResetCursor()
	end
end

-- Expand IFActionHandler
interface "IFActionHandler"
	------------------------------------------------------
	-- Property
	------------------------------------------------------
	__Doc__[[The bag id]]
	property "ItemBag" {
		Get = function(self)
			return self:GetAttribute("actiontype") == "bagslot" and tonumber(self:GetAttribute("bag"))
		end,
		Set = function(self, value)
			self:SetAction("bag", value)
		end,
		Type = Number,
	}

	__Doc__[[The slot id]]
	property "ItemSlot" {
		Get = function(self)
			return self:GetAttribute("actiontype") == "bagslot" and tonumber(self:GetAttribute("slot"))
		end,
		Set = function(self, value)
			self:SetAction("slot", value)
		end,
		Type = Number,
	}

	__Doc__[[The item's quality]]
	property "ItemQuality" { Type = NumberNil }

	__Doc__[[The item's quest status, true if actived quest, false if not actived quest, nil if not a quest item.]]
	property "ItemQuestStatus" { Type = BooleanNil }

	__Doc__[[Whether the item is a new item]]
	property "IsNewItem" { Type = Boolean }

	__Doc__[[Whether the item is a battle pay item]]
	property "IsBattlePayItem" { Type = Boolean }

	__Doc__[[Whether show the item as junk]]
	property "ShowJunkIcon" { Type = Boolean }
endinterface "IFActionHandler"