KEYED_WEEK = 604800				-- 7 Days
KEYED_RESET_US = 1467712800		-- Tue, 05 Jul 2016 00:00:00 GMT -- apparently US, Latin America, and Oceanic use the same reset... why must you be different EU!!
KEYED_RESET_EU = 1467788400		-- Mon, 06 Jul 2016 07:00:00 GMT
KEYED_RESET_CN = 1467932400		-- Wed, 07 Jul 2016 23:00:00 GMT
KEYED_RESET_TW = 1467932400
KEYED_OOD = false
KEYED_FRAME_PLAYER_HEIGHT = 16
KEYSTONES_TO_DISPLAY = 19
KEYED_SORT_ORDER_DESCENDING = false
KEYED_SORT_FUNCTION = Keyed_SortByLevel
KEYED_SORT_TYPE = "level"

-- Load Locale...
local L = LibStub("AceLocale-3.0"):GetLocale("Keyed")
local keyedRealmInfo = LibStub("LibRealmInfo");

-- Resets by region
KEYED_REGION_RESETS = {
	["US"] = KEYED_RESET_US,
	["EU"] = KEYED_RESET_EU,
	["TW"] = KEYED_RESET_TW,
	["CN"] = KEYED_RESET_CN,
};

-- Instance Names by ID
INSTANCE_NAMES = {
	-- Raids
	["1520"] = L["The Emerald Nightmare"],
	["1530"] = L["The Nighthold"],

	-- Dungeons (Post 7.2)
	["199"] = L["Black Rook Hold"],
	["210"] = L["Court of Stars"],
	["198"] = L["Darkheart Thicket"],
	["197"] = L["Eye of Azshara"],
	["200"] = L["Halls of Valor"],
	["208"] = L["Maw of Souls"],
	["206"] = L["Neltharion's Lair"],
	["209"] = L["The Arcway"],
	["207"] = L["Vault of the Wardens"],
	["233"] = L["Cathedral of Eternal Night"],
	["227"] = L["Return to Karazhan: Lower"],
	["234"] = L["Return to Karazhan: Upper"],
}

function KeyedFrame_OnShow (self)
	-- Get Keystones...
	Keyed:BroadcastKeystoneRequest(true)
end

function KeystoneListFrame_OnLoad (self)
	-- Register for events...
	KeyedFrame:RegisterAllEvents()

	-- Create List Items
	for i = 2, KEYSTONES_TO_DISPLAY do
		local button = CreateFrame ("Button", "KeystoneListFrameButton" .. i, KeystoneListFrame, "KeyedFramePlayerButtonTemplate")
		button:SetID (i)
		button:SetPoint ("TOP", _G["KeystoneListFrameButton" .. (i - 1)], "BOTTOM")
	end

	-- Set Version
	local version = GetAddOnMetadata("Keyed", "Version")
	if version then KeyedVersionText:SetText("v" .. version) end

	-- Get Keystones...
	Keyed:BroadcastKeystoneRequest(true)
end

function KeyedFrameGetKeystonesButton_OnClick()
	-- Request...
	if Keyed then
		Keyed:BroadcastKeystoneRequest()
	end
end

function KeystoneList_Update ()
	local numKeystones, keystoneData = GetKeystoneData()
	local name, dungeon, level
	local button, buttonText
	local columnTable
	local keystoneOffset = FauxScrollFrame_GetOffset (KeystoneListScrollFrame)
	local keystoneIndex
	local showScrollBar = nil;
	local level = ""
	if numKeystones > KEYSTONES_TO_DISPLAY then
		showScrollBar = 1
	end

	local SetDepleted = function(fontString)
		fontString:SetTextColor(0.6, 0.6, 0.6, 1.0)
	end
	local SetHighlighted = function(fontString)
		fontString:SetTextColor(GameFontHighlightSmall:GetTextColor())
	end
	local SetClass = function(fontString, classTable)
		fontString:SetTextColor(classTable.r, classTable.g, classTable.b, classTable.a)
	end
	local SetNormal = function(fontString)
		fontString:SetTextColor(GameFontNormalSmall:GetTextColor())
	end

	for i=1, KEYSTONES_TO_DISPLAY, 1 do
		keystoneIndex = keystoneOffset + i
		button = _G["KeystoneListFrameButton" .. i]
		button.keystoneIndex = keystoneIndex
		button.link = nil
		if keystoneIndex <= #keystoneData then
			button.playerName = keystoneData[keystoneIndex].name
			button.classColor = RAID_CLASS_COLORS[keystoneData[keystoneIndex].class]
			button.dungeon = keystoneData[keystoneIndex].dungeon
			button.level = tostring(keystoneData[keystoneIndex].level)
			button.link = keystoneData[keystoneIndex].link
			button.depleted = keystoneData[keystoneIndex].depleted
			button.ood = keystoneData[keystoneIndex].ood
			button.maxLevel = keystoneData[keystoneIndex].maxLevel
			if keystoneData[keystoneIndex].mapID ~= nil then
				button.mapName = GetMapNameFromID(keystoneData[keystoneIndex].mapID)
			end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Name"];
			buttonText:SetText(button.playerName)
			if button.classColor then SetClass(buttonText, button.classColor) else SetNormal(buttonText) end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Max"];
			buttonText:SetText(button.maxLevel)
			buttonText = _G["KeystoneListFrameButton" .. i .. "Dungeon"];
			buttonText:SetText (button.dungeon);
			if button.depleted or button.ood then SetDepleted(buttonText) else SetHighlighted(buttonText) end
			if showScrollBar then
				buttonText:SetWidth (155)
			else
				buttonText:SetWidth (185)
			end
			buttonText = _G["KeystoneListFrameButton" .. i .. "Level"];
			buttonText:SetText (button.level);
			if button.depleted or button.ood then SetDepleted(buttonText) else SetHighlighted(buttonText) end
			button:Show()
		else
			button:Hide()
		end
	end

	if showScrollBar then
		KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader3, 160);
	else
		KeyedFrameColumn_SetWidth (KeyedFrameColumnHeader3, 190);
	end

	FauxScrollFrame_Update (KeystoneListScrollFrame, numKeystones, KEYSTONES_TO_DISPLAY, KEYED_FRAME_PLAYER_HEIGHT);
end

function KeyedFrameColumn_SetWidth (frame, width)
	frame:SetWidth (width);
	_G[frame:GetName () .. "Middle"]:SetWidth (width - 9);
end

function GetKeystoneData ()
	-- Prepare
	local keyedReset = KEYED_REGION_RESETS[keyedRealmInfo.GetCurrentRegion()]
	local keyedWeek = KEYED_WEEK

	local tuesdays = math.floor((GetServerTime() - keyedReset) / keyedWeek)
	local name, dungeon, level, id, affixes
	local number = 0
	local data = {}
	local ood = false
	local maxLevel = 0
	local mapID = nil

	-- Loop through database
	if Keyed and Keyed.db.factionrealm then
		for uid, entry in pairs (Keyed.db.factionrealm) do
			ood = math.floor((entry.time - keyedReset) / keyedWeek) < tuesdays
			if entry.uid and entry.name and entry.name ~= "" then
				maxLevel = 0
				mapID = nil
				if entry.weeklybest.level and entry.weeklybest.mapID and not ood then
					maxLevel = entry.weeklybest.level
					mapID = entry.weeklybest.mapID
				end
				if entry.keystones and (#entry.keystones > 0) then
					name, dungeon, level, id, lootable, affixes = ExtractKeystoneData (entry.keystones[1])
					if name == nil then end
					-- ood = math.floor((entry.time - keyedReset) / keyedWeek) < tuesdays
					if not ood or KEYED_OOD then
						number = number + 1
						table.insert (data, {
							name = entry.name,
							class = entry.class,
							dungeon = dungeon,
							dungeonId = tonumber(id),
							level = tonumber(level),
							depleted = (tonumber(lootable) == 0),
							ood = ood,
							link = entry.keystones[1],
							maxLevel = maxLevel,
							mapID = mapID
						})
					end
				end
			end
		end
	end

	-- Sort...
	if KEYED_SORT_FUNCTION then
		table.sort (data, KEYED_SORT_FUNCTION)
	else
		table.sort(data, Keyed_SortByLevel)
	end
	
	-- Return results
	return number, data, maxLevel, mapID
end

function ExtractKeystoneData (hyperlink)
	-- |cffa335ee|Hitem:138019::::::::110:63:6160384:::1466:7:5:4:1:::|h[Mythic Keystone]|h|r
	local _, color, string, name, _, _ = strsplit ("|", hyperlink)
	
	-- Hkeystone:instMapId:level:lootable:affix1:affix2:affix3
	-- Hkeystone:233:4:1:6:0:0
	local Hitem, instMapId, plus, lootable, affixes = strsplit(':', string)
	if not Hitem == "Hkeystone" then return nil end
	local instanceName = GetMapNameFromID(instMapId)
	return name, instanceName, plus, instMapId, lootable, affixes
end

function GetMapNameFromID(mapID)
	local mapName = L["Unknown"] .. " (" .. mapID .. ")"
	if INSTANCE_NAMES[tostring(mapID)] then mapName = INSTANCE_NAMES[tostring(mapID)] end
	return mapName
end

function Keyed_SortKeyed (sort)
	
	-- Ascend or Descend?
	if KEYED_SORT_TYPE == sort then
		KEYED_SORT_ORDER_DESCENDING = not(KEYED_SORT_ORDER_DESCENDING)	-- Toggle...
	else
		KEYED_SORT_ORDER_DESCENDING = false
	end
	
	-- Set...
	KEYED_SORT_TYPE = sort
	if sort == "name" then
		KEYED_SORT_FUNCTION = Keyed_SortByName
	elseif sort == "dungeon" then
		KEYED_SORT_FUNCTION = Keyed_SortByDungeon
	elseif sort == "level" then
		KEYED_SORT_FUNCTION = Keyed_SortByLevel
	elseif sort == "max" then
		KEYED_SORT_FUNCTION = Keyed_SortByMax
	end

	-- Update
	KeystoneList_Update()
end

function Keyed_SortByName (a, b)
	local result = a.name > b.name			-- Compare by name first...
	if a.name == b.name then
		result = a.level < b.level			-- ... if name is same, compare by level...
		if a.level == b.level then
			result = a.dungeon > b.name		-- ... if level is same, compare by dungeon...
		end
	end

	-- Descend?
	if not KEYED_SORT_ORDER_DESCENDING then result = not result end
	return result
end

function Keyed_SortByDungeon (a, b)
	local result = a.dungeon > b.dungeon	-- Compare by dungeon first...
	if a.dungeon == b.dungeon then
		result = a.level < b.level			-- ... if dungeon is same, compare by level ...
		if a.level == b.level then
			result = a.name > b.name		-- ... if level is same, compare by name ...
		end
	end

	-- Descend?
	if not KEYED_SORT_ORDER_DESCENDING then result = not result end
	return result
end

function Keyed_SortByLevel (a, b)
	local lv1 = tonumber(a.level);
	local lv2 = tonumber(b.level);
	local result = lv1 < lv2;					-- Compare by level first...
	if a.level == b.level then
		result = a.name > b.name				-- ... if level is same, compare by name...
		if a.name == b.name then
			result = a.dungeon > b.dungeon		-- ... if name is same, compare by dungeon
		end
	end

	-- Descend?
	if not KEYED_SORT_ORDER_DESCENDING then result = not result end
	return result
end

function Keyed_SortByMax (a, b)
	local lv1 = tonumber(a.maxLevel);
	local lv2 = tonumber(b.maxLevel);
	local result = lv1 < lv2;					-- Compare by highest first...
	if a.maxLevel == b.maxLevel then
		result = a.level > b.level				-- ... if level is same, compare by level...
		if a.level == b.level then
			result = a.name > b.name		-- ... if level is same, compare by name
		end
	end

	-- Descend?
	if not KEYED_SORT_ORDER_DESCENDING then result = not result end
	return result
end

function KeyedFrame_ToggleOutOfDate(self, checked)
	-- Set
	local update = KEYED_OOD ~= checked
	KEYED_OOD = checked
	if update then KeystoneList_Update() end
end

function KeyedFrame_ToggleMinimap(self, checked)
	if checked then
		Keyed.db.profile.minimap.hide = false
		KeyedMinimapButton:Show("Keyed")
	else
		Keyed.db.profile.minimap.hide = true
		KeyedMinimapButton:Hide("Keyed")
	end
end

function KeyedRegionDropdown_OnLoad(self)
	
end