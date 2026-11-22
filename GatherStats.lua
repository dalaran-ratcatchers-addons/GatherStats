-- GatherStats: one-screen overview of gathered materials on all characters.
-- Item data (bags, bank, mail) comes from Syndicator, which caches every character you log in on.
-- Each category is a row of item icons with the total count; hover an icon for the per-character split.

local ICON = 36
local GAP = 4
local LABEL_W = 110
local MAX_PER_LINE = 14
local CRAFT_PER_LINE = 8
local PANEL_GAP = 24
local SECTION_GAP = 8
local PAD = 12
local TOP = 32
local BOTTOM = 40

local db
local Refresh

-- ** Categories **

local CATEGORIES = { "Ore", "Bars", "Stone", "Gems", "Metal & Stone", "Herbs", "Leather", "Cloth", "Elemental" }

-- Known vanilla materials, listed in tier order so they sort naturally
local KNOWN, ORDER = {}, {}
local nextOrder = 0
local function Add(category, ids)
	for _, id in ipairs(ids) do
		nextOrder = nextOrder + 1
		KNOWN[id] = category
		ORDER[id] = nextOrder
	end
end

Add("Ore", { 2770, 2771, 2775, 2772, 2776, 3858, 7911, 10620, 11370 })
Add("Bars", { 2840, 3576, 2841, 2842, 3575, 3859, 3577, 3860, 6037, 12359, 11371, 12360 })
Add("Stone", { 2835, 2836, 2838, 7912, 12365 })
Add("Gems", { 774, 818, 1210, 1206, 1705, 1529, 3864, 7909, 7910, 12361, 12799, 12800, 12364, 12363 })
Add("Herbs", { 2447, 765, 2449, 785, 2450, 2452, 3820, 2453, 3355, 3369, 3356, 3357, 3818, 3821, 3358, 3819,
	4625, 8153, 8831, 8836, 8838, 8839, 8845, 8846, 13464, 13463, 13465, 13466, 13467, 13468 })
Add("Leather", { 2934, 783, 2318, 4232, 2319, 4235, 4234, 8169, 4304, 8171, 8170 })
Add("Cloth", { 2589, 2592, 4306, 4338, 14047, 14256, 14342 })
Add("Elemental", { 7067, 7068, 7069, 7070 })

-- Crafted intermediate materials, shown in the right-hand panel. reagents = { itemID, count, ... }
local CRAFTED = {
	{ profession = "Blacksmithing", items = {
		{ 2862, { 2835, 1 } },	-- Rough Sharpening Stone
		{ 3239, { 2835, 1, 2589, 1 } },	-- Rough Weightstone
		{ 3470, { 2835, 2 } },	-- Rough Grinding Stone
		{ 2863, { 2836, 1 } },	-- Coarse Sharpening Stone
		{ 3240, { 2836, 1, 2592, 1 } },	-- Coarse Weightstone
		{ 3478, { 2836, 2 } },	-- Coarse Grinding Stone
		{ 2871, { 2838, 1 } },	-- Heavy Sharpening Stone
		{ 3241, { 2838, 1, 2592, 1 } },	-- Heavy Weightstone
		{ 3486, { 2838, 3 } },	-- Heavy Grinding Stone
		{ 7964, { 7912, 1 } },	-- Solid Sharpening Stone
		{ 7965, { 7912, 1, 4338, 1 } },	-- Solid Weightstone
		{ 7966, { 7912, 4 } },	-- Solid Grinding Stone
		{ 12404, { 12365, 1 } },	-- Dense Sharpening Stone
		{ 12643, { 12365, 1, 14047, 1 } },	-- Dense Weightstone
		{ 12644, { 12365, 4 } },	-- Dense Grinding Stone
		{ 7071, { 3575, 1 } },	-- Iron Buckle
		{ 6338, { 2842, 1, 3470, 2 } },	-- Silver Rod
		{ 11128, { 3577, 1, 3478, 2 } },	-- Golden Rod
		{ 11144, { 6037, 1, 3486, 1 } },	-- Truesilver Rod
	} },
	{ profession = "Engineering", items = {
		{ 4357, { 2835, 1 } },	-- Rough Blasting Powder
		{ 4359, { 2840, 1 } },	-- Handful of Copper Bolts
		{ 4361, { 2840, 2, 2880, 1 } },	-- Copper Tube
		{ 4364, { 2836, 1 } },	-- Coarse Blasting Powder
		{ 4371, { 2841, 2, 2880, 1 } },	-- Bronze Tube
		{ 4375, { 2841, 2, 2592, 1 } },	-- Whirring Bronze Gizmo
		{ 4377, { 2838, 1 } },	-- Heavy Blasting Powder
		{ 4387, { 3575, 2 } },	-- Iron Strut
		{ 10558, { 3577, 1 } },	-- Gold Power Core
		{ 4389, { 3575, 1, 10558, 1 } },	-- Gyrochronatom
		{ 10498, { 3859, 4 } },	-- Gyromatic Micro-Adjustor
		{ 10505, { 7912, 2 } },	-- Solid Blasting Powder
		{ 10559, { 3860, 3 } },	-- Mithril Tube
		{ 10560, { 3860, 1, 4338, 1, 10505, 1 } },	-- Unstable Trigger
		{ 10561, { 3860, 3 } },	-- Mithril Casing
		{ 15992, { 12365, 2 } },	-- Dense Blasting Powder
		{ 15994, { 12359, 3, 14047, 1 } },	-- Thorium Widget
	} },
	{ profession = "Leatherworking", items = {
		{ 2304, { 2318, 1 } },	-- Light Armor Kit
		{ 4231, { 783, 1, 4289, 1 } },	-- Cured Light Hide
		{ 2313, { 2319, 4, 2320, 1 } },	-- Medium Armor Kit
		{ 4233, { 4232, 1, 4289, 1 } },	-- Cured Medium Hide
		{ 4265, { 4234, 5, 2321, 1 } },	-- Heavy Armor Kit
		{ 4236, { 4235, 1, 4289, 3 } },	-- Cured Heavy Hide
		{ 8173, { 4304, 5 } },	-- Thick Armor Kit
		{ 8172, { 8169, 1, 8150, 1 } },	-- Cured Thick Hide
		{ 15564, { 8170, 5 } },	-- Rugged Armor Kit
		{ 15407, { 8171, 1, 8150, 1 } },	-- Cured Rugged Hide
	} },
	{ profession = "Tailoring", items = {
		{ 2996, { 2589, 2 } },	-- Bolt of Linen Cloth
		{ 2997, { 2592, 3 } },	-- Bolt of Woolen Cloth
		{ 4305, { 4306, 4 } },	-- Bolt of Silk Cloth
		{ 4339, { 4338, 5 } },	-- Bolt of Mageweave
		{ 14048, { 14047, 5 } },	-- Bolt of Runecloth
	} },
}

-- Items to count besides gathered materials: the crafted ones and their bought reagents
local RECIPES = {}	-- itemID -> reagents
local CRAFTED_SET, WATCH = {}, {
	[4289] = true,	-- Salt
	[8150] = true,	-- Refined Deeprock Salt
	[2880] = true,	-- Weak Flux
	[2320] = true,	-- Coarse Thread
	[2321] = true,	-- Fine Thread
}
for _, p in ipairs(CRAFTED) do
	for _, entry in ipairs(p.items) do
		CRAFTED_SET[entry[1]] = true
		WATCH[entry[1]] = true
		RECIPES[entry[1]] = entry[2]
	end
end

-- Anything else that is a Trade Good of these subclasses is picked up too (scales, essences, new items...)
local TRADEGOODS = Enum.ItemClass and Enum.ItemClass.Tradegoods or 7
local SUBCLASS_CATEGORY = { [5] = "Cloth", [6] = "Leather", [7] = "Metal & Stone", [9] = "Herbs", [10] = "Elemental" }

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local categoryCache = {}
local function Categorize(id)
	local category = categoryCache[id]
	if category ~= nil then return category end

	category = KNOWN[id]
	if CRAFTED_SET[id] then
		category = false	-- shown in the crafting panel instead (bolts, cured hides...)
	elseif not category then
		local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(id)
		if not classID then return nil end	-- not cached by the client yet, try again next refresh
		category = classID == TRADEGOODS and SUBCLASS_CATEGORY[subclassID] or false
	end
	categoryCache[id] = category
	return category
end

-- ** Data **

local function CharName(key)
	local d = Syndicator.API.GetByCharacterFullName(key).details
	local name = d.character or key
	local color = d.className and RAID_CLASS_COLORS[d.className]
	if color then
		return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
	end
	return name
end

-- counts[itemID] = { total = n, byChar = { [charKey] = { total, bags, bank, mail } } }
local function Collect()
	local counts, chars = {}, {}
	local realm = GetNormalizedRealmName()

	for _, key in ipairs(Syndicator.API.GetAllCharacters()) do
		local data = Syndicator.API.GetByCharacterFullName(key)
		local d = data and data.details
		if d and (not d.show or d.show.inventory ~= false) and (not db.realmOnly or d.realmNormalized == realm) then
			local found = false
			local function Count(slot, source)
				local id = slot.itemID
				if id and (WATCH[id] or Categorize(id)) then
					local entry = counts[id] or { total = 0, byChar = {} }
					counts[id] = entry
					local c = entry.byChar[key] or { total = 0, bags = 0, bank = 0, mail = 0 }
					entry.byChar[key] = c
					local n = slot.itemCount or 1
					c[source] = c[source] + n
					c.total = c.total + n
					entry.total = entry.total + n
					found = true
				end
			end

			for _, bag in pairs(data.bags or {}) do
				for _, slot in pairs(bag) do Count(slot, "bags") end
			end
			for _, bag in pairs(data.bank or {}) do
				for _, slot in pairs(bag) do Count(slot, "bank") end
			end
			for _, tab in pairs(data.bankTabs or {}) do
				for _, slot in pairs(tab.slots or {}) do Count(slot, "bank") end
			end
			for _, slot in pairs(data.mail or {}) do Count(slot, "mail") end

			if found then table.insert(chars, key) end
		end
	end

	table.sort(chars, function(a, b)
		local da = Syndicator.API.GetByCharacterFullName(a).details
		local db_ = Syndicator.API.GetByCharacterFullName(b).details
		if da.character ~= db_.character then return (da.character or a) < (db_.character or b) end
		return a < b
	end)
	return counts, chars
end

-- One section per category that has items: { category, items = { itemID, ... } }
local function BuildSections(counts)
	local sections = {}
	for _, category in ipairs(CATEGORIES) do
		local items = {}
		for id in pairs(counts) do
			if categoryCache[id] == category then table.insert(items, id) end
		end
		if #items > 0 then
			table.sort(items, function(a, b)
				return (ORDER[a] or (100000 + a)) < (ORDER[b] or (100000 + b))
			end)
			table.insert(sections, { category = category, items = items })
		end
	end
	return sections
end

-- ** Formatting **

local function Short(n)
	if not n or n == 0 then return "" end
	if n >= 10000 then return string.format("%dk", math.floor(n / 1000)) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(n)
end

local namesPending = false
local function ItemName(id)
	local name = C_Item.GetItemNameByID(id)
	if not name then
		C_Item.RequestLoadItemDataByID(id)
		namesPending = true
		return "item:" .. id
	end
	return name
end

-- ** UI **

local UI = CreateFrame("Frame", "GatherStatsFrame", UIParent, "BasicFrameTemplateWithInset")
UI:SetPoint("CENTER")
UI:SetFrameStrata("DIALOG")
UI:SetMovable(true)
UI:SetClampedToScreen(true)
UI:EnableMouse(true)
UI:RegisterForDrag("LeftButton")
UI:SetScript("OnDragStart", UI.StartMoving)
UI:SetScript("OnDragStop", UI.StopMovingOrSizing)
UI:Hide()
table.insert(UISpecialFrames, "GatherStatsFrame")	-- close with Escape

local title = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -5)
title:SetText("GatherStats")

local footer = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footer:SetPoint("BOTTOMLEFT", PAD + 4, 14)

local emptyText = UI:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("TOPLEFT", PAD + 4, -(TOP + 4))
emptyText:SetWidth(LABEL_W + 6 * (ICON + GAP))
emptyText:SetJustifyH("LEFT")
emptyText:SetText("No gathered materials found.\nLog in on your characters (and open their banks) so Syndicator can record them.")

local realmCheck = CreateFrame("CheckButton", nil, UI, "UICheckButtonTemplate")
realmCheck:SetSize(22, 22)
realmCheck:SetPoint("BOTTOMRIGHT", -110, 8)
local realmLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
realmLabel:SetPoint("LEFT", realmCheck, "RIGHT", 2, 0)
realmLabel:SetText("This realm only")
realmCheck:SetScript("OnClick", function(self)
	db.realmOnly = self:GetChecked() and true or false
	Refresh()
end)

local current = { counts = {}, chars = {} }

local function Owned(id)
	local entry = current.counts[id]
	return entry and entry.total or 0
end

-- How many can be crafted from the reagents on all characters together
local function CanMake(reagents)
	local n = math.huge
	for i = 1, #reagents, 2 do
		n = math.min(n, math.floor(Owned(reagents[i]) / reagents[i + 1]))
	end
	return n
end

local function ShowItemTooltip(button)
	local id = button.itemID
	local entry = current.counts[id]
	local reagents = RECIPES[id]
	if not entry and not reagents then return end

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddDoubleLine(ItemName(id), Owned(id), 1, 0.82, 0, 1, 1, 1)
	for _, key in ipairs(entry and current.chars or {}) do
		local c = entry.byChar[key]
		if c then
			GameTooltip:AddDoubleLine(CharName(key), string.format("%d  |cff808080(bags %d, bank %d, mail %d)|r",
				c.total, c.bags, c.bank, c.mail), nil, nil, nil, 1, 1, 1)
		end
	end

	if reagents then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Reagents")
		for i = 1, #reagents, 2 do
			local have, need = Owned(reagents[i]), reagents[i + 1]
			local color = have >= need and "|cff20ff20" or "|cffff4040"
			GameTooltip:AddDoubleLine(string.format("%dx %s", need, ItemName(reagents[i])),
				string.format("%s%d|r", color, have), 1, 1, 1)
		end
		GameTooltip:AddDoubleLine("Can make (all characters)", CanMake(reagents), 1, 0.82, 0, 1, 1, 1)
	end
	GameTooltip:Show()
end

-- Widget pools, reused between refreshes
local buttonPool, labelPool = {}, {}

local function GetButton(i)
	if buttonPool[i] then return buttonPool[i] end
	local button = CreateFrame("Button", nil, UI)
	button:SetSize(ICON, ICON)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetAllPoints()
	button.border:SetTexture("Interface\\Common\\WhiteIconFrame")
	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.count:SetPoint("BOTTOMRIGHT", -2, 2)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnEnter", ShowItemTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	-- Shift-click links the item in chat
	button:SetScript("OnClick", function(self)
		if IsModifiedClick("CHATLINK") then
			local _, link = C_Item.GetItemInfo(self.itemID)
			if link then ChatEdit_InsertLink(link) end
		end
	end)
	buttonPool[i] = button
	return button
end

local function SetupButton(button, id, owned)
	button.itemID = id
	button.icon:SetTexture(C_Item.GetItemIconByID(id))
	button.icon:SetDesaturated(owned == 0)
	button:SetAlpha(owned == 0 and 0.45 or 1)
	button.count:SetText(Short(owned))

	local quality = C_Item.GetItemQualityByID(id)
	local color = quality and quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then
		button.border:SetVertexColor(color.r, color.g, color.b)
		button.border:Show()
	else
		button.border:Hide()
	end
	ItemName(id)	-- warm the name cache for the tooltip
	button:Show()
end

local divider = UI:CreateTexture(nil, "ARTWORK")
divider:SetWidth(1)
divider:SetColorTexture(1, 1, 1, 0.15)

local function GetLabel(i)
	if labelPool[i] then return labelPool[i] end
	local label = UI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetWidth(LABEL_W - 8)
	label:SetJustifyH("LEFT")
	labelPool[i] = label
	return label
end

Refresh = function()
	if not UI:IsShown() then return end
	namesPending = false
	realmCheck:SetChecked(db.realmOnly)

	local counts, chars = Collect()
	current.counts, current.chars = counts, chars
	local sections = BuildSections(counts)

	local widest = 0
	for _, s in ipairs(sections) do
		widest = math.max(widest, math.min(#s.items, MAX_PER_LINE))
	end

	local y = TOP
	local b = 0
	local itemCount = 0
	for i, s in ipairs(sections) do
		local label = GetLabel(i)
		label:SetPoint("TOPLEFT", PAD + 4, -(y + (ICON - 12) / 2))
		label:SetText(s.category)
		label:Show()

		for j, id in ipairs(s.items) do
			b = b + 1
			local button = GetButton(b)
			local col = (j - 1) % MAX_PER_LINE
			local line = math.floor((j - 1) / MAX_PER_LINE)
			button:SetPoint("TOPLEFT", PAD + LABEL_W + col * (ICON + GAP), -(y + line * (ICON + GAP)))
			SetupButton(button, id, counts[id].total)
		end
		itemCount = itemCount + #s.items

		local lines = math.ceil(#s.items / MAX_PER_LINE)
		y = y + lines * (ICON + GAP) + SECTION_GAP
	end

	-- right-hand panel: crafted materials per profession, all shown (dimmed when you have none)
	local leftWidth = LABEL_W + math.max(widest, 6) * (ICON + GAP)
	local panelX = PAD + leftWidth + PANEL_GAP
	divider:SetPoint("TOPLEFT", panelX - PANEL_GAP / 2, -TOP)
	divider:SetPoint("BOTTOMLEFT", panelX - PANEL_GAP / 2, BOTTOM)
	local craftY = TOP
	local l = #sections
	for _, p in ipairs(CRAFTED) do
		l = l + 1
		local label = GetLabel(l)
		label:SetPoint("TOPLEFT", panelX, -(craftY + (ICON - 12) / 2))
		label:SetText(p.profession)
		label:Show()
		for j, entry in ipairs(p.items) do
			b = b + 1
			local button = GetButton(b)
			local col = (j - 1) % CRAFT_PER_LINE
			local line = math.floor((j - 1) / CRAFT_PER_LINE)
			button:SetPoint("TOPLEFT", panelX + LABEL_W + col * (ICON + GAP), -(craftY + line * (ICON + GAP)))
			SetupButton(button, entry[1], Owned(entry[1]))
		end
		craftY = craftY + math.ceil(#p.items / CRAFT_PER_LINE) * (ICON + GAP) + SECTION_GAP
	end

	for i = b + 1, #buttonPool do buttonPool[i]:Hide() end
	for i = l + 1, #labelPool do labelPool[i]:Hide() end

	local width = panelX + LABEL_W + CRAFT_PER_LINE * (ICON + GAP) + PAD
	local height = math.max(160, math.max(y, craftY) + BOTTOM)
	UI:SetSize(width, height)
	UI:SetScale(math.min(1, UIParent:GetWidth() * 0.96 / width, UIParent:GetHeight() * 0.94 / height))

	emptyText:SetShown(#sections == 0)
	footer:SetFormattedText("%d materials on %d characters", itemCount, #chars)
end

local refreshQueued = false
local function QueueRefresh()
	if refreshQueued or not UI:IsShown() then return end
	refreshQueued = true
	C_Timer.After(0.3, function()
		refreshQueued = false
		Refresh()
	end)
end

UI:SetScript("OnShow", function() Refresh() end)

function GatherStats_Toggle()
	UI:SetShown(not UI:IsShown())
end

SLASH_GATHERSTATS1 = "/gather"
SLASH_GATHERSTATS2 = "/gs"
SlashCmdList.GATHERSTATS = GatherStats_Toggle

-- ** Events **

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		GatherStatsDB = GatherStatsDB or {}
		db = GatherStatsDB

		local owner = {}
		for _, name in ipairs({ "BagCacheUpdate", "MailCacheUpdate", "CharacterDeleted" }) do
			Syndicator.CallbackRegistry:RegisterCallback(name, QueueRefresh, owner)
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" and namesPending then
		QueueRefresh()
	end
end)
