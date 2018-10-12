
local AddonName, HubData = ...;
local LocalVars = TidyPlatesHubDefaults



-- Widget Helpers
local WidgetLib = TidyPlatesWidgets

local CreateThreatLineWidget = WidgetLib.CreateThreatLineWidget
local CreateAuraWidget = WidgetLib.CreateAuraWidget
local CreateClassWidget = WidgetLib.CreateClassWidget
local CreateRangeWidget = WidgetLib.CreateRangeWidget
local CreateComboPointWidget = WidgetLib.CreateComboPointWidget
local CreateTotemIconWidget = WidgetLib.CreateTotemIconWidget

TidyPlatesHubDefaults.WidgetsRangeMode = 1
TidyPlatesHubMenus.RangeModes = {
				{ text = "9 yards"} ,
				{ text = "15 yards" } ,
				{ text = "28 yards" } ,
				{ text = "40 yards" } ,
			}

TidyPlatesHubDefaults.WidgetsDebuffStyle = 1
TidyPlatesHubMenus.DebuffStyles = {
				{ text = "Wide",  } ,
				{ text = "Compact (May require UI reload to take effect)",  } ,
			}

------------------------------------------------------------------------------
-- Aura Widget
------------------------------------------------------------------------------
TidyPlatesHubPrefixList = {
	-- ALL
	["ALL"] = 1,
	["All"] = 1,
	["all"] = 1,

	-- MY
	["MY"] = 2,
	["My"] = 2,
	["my"] = 2,

	-- OTHER
	["OTHER"] = 3,
	["Other"] = 3,
	["other"] = 3,

	-- CC
	["CC"] = 4,
	["cc"] = 4,
	["Cc"] = 4,

	-- NOT
	["NOT"] = 5,
	["Not"] = 5,
	["not"] = 5,
}

--[[
* Debuffs are color coded, with poison debuffs having a green border,
magic debuffs a blue border, physical debuffs a red border, diseases a
brown border, and curses a purple border

Information from Widget:
aura.spellid, aura.name, aura.expiration, aura.stacks,
aura.caster, aura.duration, aura.texture,
aura.type, aura.reaction
--]]

local AURA_TYPE_DEBUFF = 6
local AURA_TYPE_BUFF = 1

local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2

local AURA_TYPE = { "Buff", "Curse", "Disease", "Magic", "Poison", "Debuff", }
local AURA_TYPE_COLORS = { nil, {1,0,1}, {.5, .2, 0}, {0,.4,1}, {0,1,0}, nil, }




local function GetPrefixPriority(aura)
	local spellid = tostring(aura.spellid)
	local name = aura.name
	-- Lookup using the Prefix & Priority Lists
	local prefix = LocalVars.WidgetsDebuffLookup[spellid] or LocalVars.WidgetsDebuffLookup[name]
	local priority = LocalVars.WidgetsDebuffPriority[spellid] or LocalVars.WidgetsDebuffPriority[name]

	return prefix, priority
end

local function GetAuraColor(aura)
	local color = AURA_TYPE_COLORS[aura.type]
	if color then return unpack(color) end
end

local DebuffPrefixModes = {
	-- All
	function(aura)
		return true
	end,
	-- My
	function(aura)
		if aura.caster == "player" or aura.caster == "pet" then return true end
	end,
	-- Other
	function(aura)
		--print(aura.caster, aura.name)
		if (aura.caster ~= "player" or aura.caster ~= "pet") then return true end
	end,
	-- CC
	function(aura)
		--return true, .5, .4, 0
		return true, 1, 1, 0
	end,
	-- NOT
	function(aura)
		return false
	end
}

local function SmartFilterMode(aura)
	local ShowThisAura = false
	local AuraPriority = 20		-- default priority


	-- My own Buffs and Debuffs
	if (aura.caster == "player" or aura.caster == "pet") and aura.duration and aura.duration < 150 then
		if LocalVars.WidgetsMyBuff and aura.effect == "HELPFUL" then
			ShowThisAura = true
		elseif LocalVars.WidgetsMyDebuff and aura.effect == "HARMFUL" then
			ShowThisAura = true
		end
	end

	-- Evaluate prefix (tag) and list order (priority) for further filtering
	local prefix, priority = GetPrefixPriority(aura)

	-- If the aura is mentioned in the list, evaluate the instruction...
	if prefix then
		local show = DebuffPrefixModes[prefix](aura)

		if show == true then
			return true, 20 + (priority or 0)		-- , r, g, b
		else
			return false
		end

	--- When no prefix is mentioned, return the aura.
	else
		return ShowThisAura, 20		-- , r, g, b
	end

end




local DispelTypeHandlers = {
	-- Curse
	["Curse"] = function()
		return LocalVars.WidgetAuraTrackCurse
	end,
	-- Disease
	["Disease"] = function()
		return LocalVars.WidgetAuraTrackDisease
	end,
	-- Magic
	["Magic"] = function()
		return LocalVars.WidgetAuraTrackMagic
	end,
	-- Poison
	["Poison"] = function()
		return LocalVars.WidgetAuraTrackPoison
	end,
	}



local function TrackDispelType(dispelType)
	if dispelType then
		local handlerfunction = DispelTypeHandlers[dispelType]
		if handlerfunction then return handlerfunction() end
	end
end



local function DebuffFilter(aura)

	-- AuraWidget:
	--  show, priority, r, g, b = AuraFilterFunction(aura)

	if LocalVars.WidgetAuraTrackDispelFriendly and aura.reaction == AURA_TARGET_FRIENDLY then
		if aura.effect == "HARMFUL" and TrackDispelType(aura.type) then
		local r, g, b = GetAuraColor(aura)
		return true, 10, r, g, b end
	end

	if aura.name == "Coat of Thistlefur" then
		print("Thistlefur")
		return true, 9, .15, .6, 1
	end

	return SmartFilterMode(aura)
end


---------------------------------------------------------------------------------------------------------
-- Widget Initializers
---------------------------------------------------------------------------------------------------------

local function InitWidget( widgetName, plate, config, createFunction, enabled)
	local widget = plate.widgets[widgetName]

	if enabled and createFunction and config then

		if widget then
			if widget.UpdateConfig then widget:UpdateConfig() end
		else
			widget = createFunction(plate)
			plate.widgets[widgetName] = widget
		end

		widget:SetPoint(config.anchor or "TOP", plate, config.x or 0, config.y or 0)

	elseif widget and widget.Hide then
		widget:Hide()
	end

end



------------------------------------------------------------------------------
-- Widget Activation
------------------------------------------------------------------------------
local function OnInitializeWidgets(plate, configTable)

	local EnableClassWidget = (LocalVars.ClassEnemyIcon or LocalVars.ClassPartyIcon)
	local EnableTotemWidget = LocalVars.WidgetsTotemIcon
	local EnableComboWidget = LocalVars.WidgetsComboPoints
	local EnableThreatWidget = LocalVars.WidgetsThreatIndicator
	local EnableAuraWidget = LocalVars.WidgetsDebuff

	InitWidget( "ClassWidget", plate, configTable.ClassIcon, CreateClassWidget, EnableClassWidget)
	InitWidget( "TotemWidget", plate, configTable.TotemIcon, CreateTotemIconWidget, EnableTotemWidget)
	InitWidget( "ComboWidget", plate, configTable.ComboWidget, CreateComboPointWidget, EnableComboWidget)
	InitWidget( "ThreatWidget", plate, configTable.ThreatLineWidget, CreateThreatLineWidget, EnableThreatWidget)

	if EnableComboWidget and configTable.DebuffWidgetPlus then
		InitWidget( "AuraWidget", plate, configTable.DebuffWidgetPlus, CreateAuraWidget, EnableAuraWidget)
	else
		InitWidget( "AuraWidget", plate, configTable.DebuffWidget, CreateAuraWidget, EnableAuraWidget)
	end

end

local function OnContextUpdateDelegate(plate, unit)
	local widgets = plate.widgets

	if LocalVars.WidgetsComboPoints and widgets.ComboWidget then
		widgets.ComboWidget:UpdateContext(plate, unit) end

	if LocalVars.WidgetsThreatIndicator and widgets.ThreatWidget then
		widgets.ThreatWidget:UpdateContext(unit) end		-- Tug-O-Threat

	if LocalVars.WidgetsDebuff and widgets.AuraWidget then
		widgets.AuraWidget:UpdateContext(unit) end
end

local function OnUpdateDelegate(plate, unit)
	local widgets = plate.widgets

	if widgets.ClassWidget and ( (LocalVars.ClassEnemyIcon and unit.reaction ~= "FRIENDLY") or (LocalVars.ClassPartyIcon and unit.reaction == "FRIENDLY")) then
		widgets.ClassWidget:Update(unit, LocalVars.ClassPartyIcon)
	end

	if LocalVars.WidgetsTotemIcon and widgets.TotemWidget then
		widgets.TotemWidget:Update(unit)
	end
end


------------------------------------------------------------------------------
-- Local Variable
------------------------------------------------------------------------------

local function OnVariableChange(vars)

	LocalVars = vars

	if LocalVars.WidgetsDebuff then
		TidyPlatesWidgets:EnableAuraWatcher()
		TidyPlatesWidgets.SetAuraFilter(DebuffFilter)
	else TidyPlatesWidgets:DisableAuraWatcher() end
end
HubData.RegisterCallback(OnVariableChange)


------------------------------------------------------------------------------
-- Add References
------------------------------------------------------------------------------

TidyPlatesHubFunctions.OnUpdate = OnUpdateDelegate
TidyPlatesHubFunctions.OnInitializeWidgets = OnInitializeWidgets
TidyPlatesHubFunctions.OnContextUpdate = OnContextUpdateDelegate
TidyPlatesHubFunctions._WidgetDebuffFilter = DebuffFilter







local AddonName, HubData = ...;
local LocalVars = TidyPlatesHubDefaults



-- Widget Helpers
local WidgetLib = TidyPlatesWidgets

local CreateThreatLineWidget = WidgetLib.CreateThreatLineWidget
local CreateAuraWidget = WidgetLib.CreateAuraWidget
local CreateClassWidget = WidgetLib.CreateClassWidget
local CreateRangeWidget = WidgetLib.CreateRangeWidget
local CreateComboPointWidget = WidgetLib.CreateComboPointWidget
local CreateTotemIconWidget = WidgetLib.CreateTotemIconWidget

TidyPlatesHubDefaults.WidgetsRangeMode = 1
TidyPlatesHubMenus.RangeModes = {
				{ text = "9 yards"} ,
				{ text = "15 yards" } ,
				{ text = "28 yards" } ,
				{ text = "40 yards" } ,
			}

TidyPlatesHubDefaults.WidgetsDebuffStyle = 1
TidyPlatesHubMenus.DebuffStyles = {
				{ text = "Wide",  } ,
				{ text = "Compact (May require UI reload to take effect)",  } ,
			}

------------------------------------------------------------------------------
-- Aura Widget
------------------------------------------------------------------------------
TidyPlatesHubPrefixList = {
	-- ALL
	["ALL"] = 1,
	["All"] = 1,
	["all"] = 1,

	-- MY
	["MY"] = 2,
	["My"] = 2,
	["my"] = 2,

	-- OTHER
	["OTHER"] = 3,
	["Other"] = 3,
	["other"] = 3,

	-- CC
	["CC"] = 4,
	["cc"] = 4,
	["Cc"] = 4,

	-- NOT
	["NOT"] = 5,
	["Not"] = 5,
	["not"] = 5,
}

--[[
* Debuffs are color coded, with poison debuffs having a green border,
magic debuffs a blue border, physical debuffs a red border, diseases a
brown border, and curses a purple border

Information from Widget:
aura.spellid, aura.name, aura.expiration, aura.stacks,
aura.caster, aura.duration, aura.texture,
aura.type, aura.reaction
--]]

local AURA_TYPE_DEBUFF = 6
local AURA_TYPE_BUFF = 1

local AURA_TARGET_HOSTILE = 1
local AURA_TARGET_FRIENDLY = 2

local AURA_TYPE = { "Buff", "Curse", "Disease", "Magic", "Poison", "Debuff", }
local AURA_TYPE_COLORS = { nil, {1,0,1}, {.5, .2, 0}, {0,.4,1}, {0,1,0}, nil, }



local function GetPrefixPriority(aura)
	local spellid = tostring(aura.spellid)
	local name = aura.name
	-- Lookup using the Prefix & Priority Lists
	local prefix = LocalVars.WidgetsDebuffLookup[spellid] or LocalVars.WidgetsDebuffLookup[name]
	local priority = LocalVars.WidgetsDebuffPriority[spellid] or LocalVars.WidgetsDebuffPriority[name]

	return prefix, priority
end

local function GetAuraColor(aura)
	local color = AURA_TYPE_COLORS[aura.type]
	if color then return unpack(color) end
end

local DebuffPrefixModes = {
	-- All
	function(aura)
		return true
	end,
	-- My
	function(aura)
		if aura.caster == "player" or aura.caster == "pet" then return true end
	end,
	-- Other
	function(aura)
		--print(aura.caster, aura.name)
		if (aura.caster ~= "player" or aura.caster ~= "pet") then return true end
	end,
	-- CC
	function(aura)
		--return true, .5, .4, 0
		return true, 1, 1, 0
	end,
	-- NOT
	function(aura)
		return false
	end
}

local function SmartFilterMode(aura)
	local ShowThisAura = false
	local AuraPriority = 20


	-- My own Buffs and Debuffs
	if (aura.caster == "player" or aura.caster == "pet") and aura.duration and aura.duration < 150 then
		if LocalVars.WidgetsMyBuff and aura.effect == "HELPFUL" then
			ShowThisAura = true
		elseif LocalVars.WidgetsMyDebuff and aura.effect == "HARMFUL" then
			ShowThisAura = true
		end
	end


	-- Evaluate for further filtering
	local prefix, priority = GetPrefixPriority(aura)
	-- If the aura is mentioned in the list, evaluate the instruction...
	if prefix then
		local show = DebuffPrefixModes[prefix](aura)

		--print(aura.name, show, prefix, priority)
		if show == true then
			return true, 20 + (priority or 0)		-- , r, g, b
		else
			return false
		end
	--- When no prefix is mentioned, return the aura.
	else
		return ShowThisAura, 20		-- , r, g, b
	end

end




local DispelTypeHandlers = {
	-- Curse
	["Curse"] = function()
		return LocalVars.WidgetAuraTrackCurse
	end,
	-- Disease
	["Disease"] = function()
		return LocalVars.WidgetAuraTrackDisease
	end,
	-- Magic
	["Magic"] = function()
		return LocalVars.WidgetAuraTrackMagic
	end,
	-- Poison
	["Poison"] = function()
		return LocalVars.WidgetAuraTrackPoison
	end,
	}

local function TrackDispelType(dispelType)
	if dispelType then
		local handlerfunction = DispelTypeHandlers[dispelType]
		if handlerfunction then return handlerfunction() end
	end
end

local function DebuffFilter(aura)
	if LocalVars.WidgetAuraTrackDispelFriendly and aura.reaction == AURA_TARGET_FRIENDLY then
		if aura.effect == "HARMFUL" and TrackDispelType(aura.type) then
		local r, g, b = GetAuraColor(aura)
		return true, 10, r, g, b end
	end

	return SmartFilterMode(aura)
end


---------------------------------------------------------------------------------------------------------
-- Widget Initializers
---------------------------------------------------------------------------------------------------------

local function InitWidget( widgetName, extended, config, createFunction, enabled)
	local widget = extended.widgets[widgetName]

	if enabled and createFunction and config then

		if widget then
			if widget.UpdateConfig then widget:UpdateConfig() end
		else
			widget = createFunction(extended.widgetParent)
			extended.widgets[widgetName] = widget
		end

		widget:SetPoint(config.anchor or "TOP", extended, config.x or 0, config.y or 0)

	elseif widget and widget.Hide then
		widget:Hide()
	end

end



------------------------------------------------------------------------------
-- Widget Activation
------------------------------------------------------------------------------
local function OnInitializeWidgets(extended, configTable)

	local EnableClassWidget = (LocalVars.ClassEnemyIcon or LocalVars.ClassPartyIcon)
	local EnableTotemWidget = LocalVars.WidgetsTotemIcon
	local EnableComboWidget = LocalVars.WidgetsComboPoints
	local EnableThreatWidget = LocalVars.WidgetsThreatIndicator
	local EnableAuraWidget = LocalVars.WidgetsDebuff

	InitWidget( "ClassWidgetHub", extended, configTable.ClassIcon, CreateClassWidget, EnableClassWidget)
	InitWidget( "TotemWidgetHub", extended, configTable.TotemIcon, CreateTotemIconWidget, EnableTotemWidget)
	InitWidget( "ComboWidgetHub", extended, configTable.ComboWidget, CreateComboPointWidget, EnableComboWidget)
	InitWidget( "ThreatWidgetHub", extended, configTable.ThreatLineWidget, CreateThreatLineWidget, EnableThreatWidget)

	if EnableComboWidget and configTable.DebuffWidgetPlus then
		InitWidget( "AuraWidgetHub", extended, configTable.DebuffWidgetPlus, CreateAuraWidget, EnableAuraWidget)
	else
		InitWidget( "AuraWidgetHub", extended, configTable.DebuffWidget, CreateAuraWidget, EnableAuraWidget)
	end

end

local function OnContextUpdateDelegate(extended, unit)
	local widgets = extended.widgets

	if LocalVars.WidgetsComboPoints and widgets.ComboWidgetHub then
		widgets.ComboWidgetHub:UpdateContext(unit) end

	if LocalVars.WidgetsThreatIndicator and widgets.ThreatWidgetHub then
		widgets.ThreatWidgetHub:UpdateContext(unit) end		-- Tug-O-Threat

	if LocalVars.WidgetsDebuff and widgets.AuraWidgetHub then
		widgets.AuraWidgetHub:UpdateContext(unit) end
end

local function OnUpdateDelegate(extended, unit)
	local widgets = extended.widgets

	if widgets.ClassWidgetHub and ( (LocalVars.ClassEnemyIcon and unit.reaction ~= "FRIENDLY") or (LocalVars.ClassPartyIcon and unit.reaction == "FRIENDLY")) then
		widgets.ClassWidgetHub:Update(unit, LocalVars.ClassPartyIcon)
	end

	if LocalVars.WidgetsTotemIcon and widgets.TotemWidgetHub then
		widgets.TotemWidgetHub:Update(unit)
	end
end


------------------------------------------------------------------------------
-- Local Variable
------------------------------------------------------------------------------

local function OnVariableChange(vars)

	LocalVars = vars

	if LocalVars.WidgetsDebuff then
		TidyPlatesWidgets:EnableAuraWatcher()
		TidyPlatesWidgets.SetAuraFilter(DebuffFilter)
	else TidyPlatesWidgets:DisableAuraWatcher() end
end
HubData.RegisterCallback(OnVariableChange)


------------------------------------------------------------------------------
-- Add References
------------------------------------------------------------------------------

TidyPlatesHubFunctions.OnUpdate = OnUpdateDelegate
TidyPlatesHubFunctions.OnInitializeWidgets = OnInitializeWidgets
TidyPlatesHubFunctions.OnContextUpdate = OnContextUpdateDelegate
TidyPlatesHubFunctions._WidgetDebuffFilter = DebuffFilter






