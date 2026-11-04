-- Custom Loadout: Obsidian Mod Manager entry script.
--
-- The loadout screen's single PERKS box becomes four slots (Perk, Sidearm,
-- Grenades, Equipment), and the Saber can be carried as a sidearm. The mod
-- replaces no game files: it patches LoadoutSettings, InventoryComponent and
-- MenuScreenLoadout when the game requires them, so it runs on top of whichever
-- versions of those scripts are deployed (the Steam game's, or the 16-slot ones
-- from the 16 Players mod).
--
-- Saved loadouts keep `perk` (the Equipment slot, the perk the game networks) and
-- `sidearm_weapon`, and add `perk_slot` and `grenade`. The game ignores the new
-- fields, so switching the mod off leaves a normal loadout.
--
-- Scope: session. Obsidian decides per lobby whether session mods may run
-- (obsidian.session.cleared()). The loadout screen asks once, when it opens, and
-- keeps that answer until it closes, so the screen never mixes the two layouts if
-- someone joins or leaves meanwhile. A player spawned while session mods are off
-- gets the game's own loadout: the Equipment perk and the standard pistol and
-- grenades.

local CL = rawget(_G, "CUSTOM_LOADOUT") or {}

rawset(_G, "CUSTOM_LOADOUT", CL)

CL.version = "1.0.0"
CL.obsidian = rawget(_G, "obsidian")

local function log(arg_log_0, ...)
	local var_log_0 = CL.obsidian

	if var_log_0 and var_log_0.log then
		var_log_0.log(string.format(arg_log_0, ...))
	end
end

-- True when Obsidian lets session mods run in the current lobby (always true if
-- the API has no session query).
function CL.active()
	local var_active_0 = CL.obsidian and CL.obsidian.session

	if var_active_0 and type(var_active_0.cleared) == "function" then
		return var_active_0.cleared() == true
	end

	return true
end

-- LoadoutSettings: slot tables, the Saber sidearm entry and migrate_loadout.
local function patch_settings()
	if LoadoutSettings.MOD_CUSTOM_LOADOUT then
		return
	end

	-- Custom loadout mod: the single perk slot becomes four slots (Perk, Sidearm,
	-- Grenades, Equipment) and the Saber becomes a sidearm.
	-- Saved loadouts keep `perk` (the Equipment slot, which is the networked perk)
	-- and `sidearm_weapon`, and add `perk_slot` and `grenade`.

	LoadoutSettings.MOD_CUSTOM_LOADOUT = true

	LoadoutSettings.sidearm_weapon[#LoadoutSettings.sidearm_weapon + 1] = {
		description = "weapon_saber_d",
		name = "weapon_saber",
		unit_path = "equipment/wep_saber_01",
		icon = "wepicon_saber_01",
		hide_in_armory = true,
		attributes = {
			attr_spec_melee = true,
			attr_spec_sidearm = true
		},
		upgrades = {}
	}

	local var_0_mod_sidearm_perks = {
		weapon_revolver = "perk_revolver_sidearm",
		weapon_flamepistol = "perk_flamepistol_sidearm",
		weapon_plasmapistol = "perk_plasmapistol_sidearm"
	}

	for iter_0_mod_0, iter_0_mod_1 in ipairs(LoadoutSettings.sidearm_weapon) do
		local var_0_mod_0 = var_0_mod_sidearm_perks[iter_0_mod_1.name]

		if var_0_mod_0 then
			iter_0_mod_1.unlock_perk = var_0_mod_0
			iter_0_mod_1.loc_name = var_0_mod_0
			iter_0_mod_1.loc_description = var_0_mod_0 .. "_d"
		end
	end

	local function var_0_mod_perk_entries(arg_0_mod_0, arg_0_mod_1)
		local var_0_mod_1 = {
			arg_0_mod_0
		}

		for iter_0_mod_2, iter_0_mod_3 in ipairs(arg_0_mod_1) do
			local var_0_mod_2 = LoadoutSettings.get_item("perks", iter_0_mod_3)

			if var_0_mod_2 then
				var_0_mod_2 = table.clone(var_0_mod_2)
				var_0_mod_2.unlock_perk = var_0_mod_2.name
				var_0_mod_1[#var_0_mod_1 + 1] = var_0_mod_2
			end
		end

		return var_0_mod_1
	end

	LoadoutSettings.perk_slot = var_0_mod_perk_entries({
		description = "perk_none_d",
		name = "perk_none"
	}, {
		"perk_stratagem_expert",
		"perk_cardio",
		"perk_strong_arm",
		"perk_precision_call_in"
	})
	LoadoutSettings.grenade_slot = var_0_mod_perk_entries({
		description = "grenade_default_d",
		name = "grenade_default"
	}, {
		"perk_grenade_stun",
		"perk_grenade_smoke",
		"perk_grenade_incendiary"
	})
	LoadoutSettings.equipment_perks = {
		"perk_lasersight",
		"perk_heavy_armor",
		"perk_adrenaline",
		"perk_teleport_shield",
		"perk_all_terrain_boots"
	}

	-- type: LoadoutSettings list the slot picks from; field: key in the saved loadout.
	LoadoutSettings.loadout_slots = {
		{
			type = "perk_slot",
			field = "perk_slot",
			title = "loadout_slot_perk",
			default = "perk_none"
		},
		{
			type = "sidearm_weapon",
			field = "sidearm_weapon",
			title = "loadout_slot_sidearm",
			default = "weapon_pistol"
		},
		{
			type = "grenade_slot",
			field = "grenade",
			title = "loadout_slot_grenades",
			default = "grenade_default"
		},
		{
			type = "perks",
			field = "perk",
			title = "loadout_slot_equipment",
			default = "perk_lasersight"
		}
	}

	-- Perks applied on top of `perk` when a player spawns (see InventoryComponent.set_loadout).
	LoadoutSettings.extra_perk_fields = {
		"perk_slot",
		"grenade"
	}

	function LoadoutSettings.get_loadout_slot(arg_0_mod_2)
		for iter_0_mod_4, iter_0_mod_5 in ipairs(LoadoutSettings.loadout_slots) do
			if iter_0_mod_5.type == arg_0_mod_2 then
				return iter_0_mod_5
			end
		end

		return nil
	end

	function LoadoutSettings.is_equipment_perk(arg_0_mod_3)
		for iter_0_mod_6, iter_0_mod_7 in ipairs(LoadoutSettings.equipment_perks) do
			if iter_0_mod_7 == arg_0_mod_3 then
				return true
			end
		end

		return false
	end

	-- Moves a vanilla single-perk loadout into the four slots and fills empty slots.
	function LoadoutSettings.migrate_loadout(arg_0_mod_4)
		if type(arg_0_mod_4) ~= "table" then
			return arg_0_mod_4
		end

		local var_0_mod_3 = arg_0_mod_4.perk

		if var_0_mod_3 and not LoadoutSettings.is_equipment_perk(var_0_mod_3) then
			for iter_0_mod_8, iter_0_mod_9 in pairs(var_0_mod_sidearm_perks) do
				if iter_0_mod_9 == var_0_mod_3 then
					if arg_0_mod_4.sidearm_weapon == nil or arg_0_mod_4.sidearm_weapon == LoadoutSettings.default_loadout.sidearm_weapon then
						arg_0_mod_4.sidearm_weapon = iter_0_mod_8
					end

					var_0_mod_3 = nil
				end
			end

			if var_0_mod_3 and LoadoutSettings.get_item("grenade_slot", var_0_mod_3) then
				arg_0_mod_4.grenade = arg_0_mod_4.grenade or var_0_mod_3
				var_0_mod_3 = nil
			end

			if var_0_mod_3 and LoadoutSettings.get_item("perk_slot", var_0_mod_3) then
				arg_0_mod_4.perk_slot = arg_0_mod_4.perk_slot or var_0_mod_3
			end

			arg_0_mod_4.perk = LoadoutSettings.default_loadout.perk
		end

		for iter_0_mod_10, iter_0_mod_11 in ipairs(LoadoutSettings.loadout_slots) do
			local var_0_mod_4 = arg_0_mod_4[iter_0_mod_11.field]

			if var_0_mod_4 == nil or LoadoutSettings.get_item(iter_0_mod_11.type, var_0_mod_4) == nil then
				arg_0_mod_4[iter_0_mod_11.field] = iter_0_mod_11.default
			end
		end

		-- Support weapons are Proving Grounds only; a saved loadout holding one gets the default.
		local var_0_mod_5 = arg_0_mod_4.primary_weapon

		if var_0_mod_5 ~= nil then
			local var_0_mod_6 = LoadoutSettings.get_item("primary_weapon", var_0_mod_5)

			if var_0_mod_6 and var_0_mod_6.group == "support" then
				arg_0_mod_4.primary_weapon = LoadoutSettings.default_loadout.primary_weapon
			end
		end

		return arg_0_mod_4
	end

	log("custom loadout %s: loadout settings patched", CL.version)
end

-- InventoryComponent.set_loadout: when the mod is active the Perk and Grenades
-- slots are applied as extra perks after the game's own set_loadout (all their
-- effects are queued commands, so the order does not matter). Only master-side
-- effects run; the networked `perk` stays the Equipment slot. When session mods
-- are off, the standard pistol replaces a modded sidearm choice.

-- The loadout set_loadout would read (same lookup as the game's set_loadout).
local function saved_loadout(arg_23_3)
	local var_23_1

	if arg_23_3 and arg_23_3.pad_number then
		local var_23_3 = arg_23_3.pad_number
		local var_23_4 = UserManager:get_user_id(var_23_3)

		if IS_PS4 or var_23_3 == GameSettings.get_main_pad_number() then
			local var_23_5 = string.sub(arg_23_3.loadout_prefix, 1, -2)

			var_23_1 = SaveManager:user_get(var_23_5, var_23_4)

			if SaveManager:user_get("use_random_loadout", var_23_4) then
				var_23_1 = SaveManager:user_get("random_loadout", var_23_4)
			end
		else
			var_23_1 = SaveManager:get(arg_23_3.loadout_prefix .. tostring(var_23_3))

			if SaveManager:get("use_random_loadout_" .. tostring(var_23_3)) then
				var_23_1 = SaveManager:get("random_loadout_" .. tostring(var_23_3))
			end
		end

		if SaveManager:get("use_proving_grounds_loadout") then
			var_23_1 = SaveManager:get("proving_grounds_loadout")
		end
	end

	return var_23_1 or LoadoutSettings.default_loadout
end

local function apply_extra_perks(arg_23_0, arg_23_1, var_23_0, var_23_1)
	var_23_0.extra_perks = {}

	for iter_23_mod_0, iter_23_mod_1 in ipairs(LoadoutSettings.extra_perk_fields or {}) do
		local var_23_mod_0 = var_23_1[iter_23_mod_1]
		local var_23_mod_1 = var_23_mod_0 and PerkSettings[var_23_mod_0]

		if var_23_mod_1 and var_23_mod_0 ~= var_23_1.perk and LoadoutSettings.get_item_id_by_name("perks", var_23_mod_0) > 0 then
			local var_23_mod_2 = {}

			var_23_0.extra_perks[#var_23_0.extra_perks + 1] = var_23_mod_0

			if var_23_mod_1.setup_master then
				var_23_mod_1.setup_master(arg_23_1, arg_23_0, var_23_mod_2, var_23_1)
			end

			if var_23_mod_1.setup_slave and not var_23_mod_1.update_slave and not var_23_mod_1.remove_slave then
				var_23_mod_1.setup_slave(arg_23_1, arg_23_0, var_23_mod_2)
			end
		end
	end
end

local function patch_inventory()
	local var_inv_0 = InventoryComponent

	if var_inv_0.mod_custom_loadout then
		return
	end

	var_inv_0.mod_custom_loadout = true

	local var_inv_1 = var_inv_0.set_loadout

	function var_inv_0.set_loadout(arg_23_0, arg_23_1, arg_23_2, arg_23_3, arg_23_4)
		local var_23_1 = saved_loadout(arg_23_3)

		if arg_23_4 then
			var_23_1 = arg_23_4
		end

		if type(var_23_1) ~= "table" or not LoadoutSettings.migrate_loadout then
			return var_inv_1(arg_23_0, arg_23_1, arg_23_2, arg_23_3, arg_23_4)
		end

		var_23_1 = table.clone(var_23_1)

		if not CL.active() then
			if var_23_1.sidearm_weapon ~= nil then
				var_23_1.sidearm_weapon = LoadoutSettings.default_loadout.sidearm_weapon
			end

			return var_inv_1(arg_23_0, arg_23_1, arg_23_2, arg_23_3, var_23_1)
		end

		-- migrate_loadout also swaps a saved Proving Grounds primary for the default;
		-- a Proving Grounds trial hands its own loadout in here, so keep the primary.
		local var_23_mod_3 = var_23_1.primary_weapon

		LoadoutSettings.migrate_loadout(var_23_1)

		var_23_1.primary_weapon = var_23_mod_3

		local var_23_mod_4 = var_inv_1(arg_23_0, arg_23_1, arg_23_2, arg_23_3, var_23_1)

		apply_extra_perks(arg_23_0, arg_23_1, arg_23_2.state, var_23_1)

		return var_23_mod_4
	end

	log("custom loadout %s: inventory patched", CL.version)
end

-- MenuScreenLoadout: the modded screen functions. They use the screen's own file
-- constants, except that the primary weapon is entry 5 of loadout_menu (after the
-- four slots) instead of 2.
local var_0_0 = 60
local var_0_1 = 20
local var_0_2 = 1
local var_0_3 = 2
local var_0_4 = 3
local var_0_5 = 4
local var_0_6 = 1
local var_0_7 = 5

-- Custom loadout mod: loadout_menu holds the four slots (1-4), the primary
-- weapon (var_0_7), four stratagems and the confirm button. English fallbacks
-- are used for keys the game's string table does not have.
local var_0_mod_strings = {
	loadout_slot_perk = "PERK",
	loadout_slot_sidearm = "SIDEARM",
	loadout_slot_grenades = "GRENADES",
	loadout_slot_equipment = "EQUIPMENT",
	perk_none = "None",
	perk_none_d = "No perk in this slot. Unlock more perks by ranking up.",
	grenade_default = "Standard Grenades",
	grenade_default_d = "The standard-issue Helldiver grenade.",
	weapon_saber_d = "A close combat blade carried as a sidearm. Normally only issued in the Proving Grounds."
}

local function var_0_mod_loc(arg_0_mod_0)
	local var_0_mod_0 = LocalizationManager:string(arg_0_mod_0)
	local var_0_mod_1 = var_0_mod_strings[arg_0_mod_0]

	if var_0_mod_1 and (var_0_mod_0 == nil or var_0_mod_0 == arg_0_mod_0 or string.sub(var_0_mod_0, 1, 4) == "LOC:") then
		return var_0_mod_1
	end

	return var_0_mod_0
end

local function var_0_mod_item_name(arg_0_mod_1)
	if not arg_0_mod_1 then
		return "-"
	end

	return var_0_mod_loc(arg_0_mod_1.loc_name or arg_0_mod_1.name)
end

local function var_0_mod_item_description(arg_0_mod_2)
	return arg_0_mod_2.loc_description or arg_0_mod_2.description
end

local function var_0_mod_slot_available(arg_0_mod_3, arg_0_mod_4, arg_0_mod_5, arg_0_mod_6, arg_0_mod_7)
	local var_0_mod_2 = arg_0_mod_3.unlock_perk

	if not var_0_mod_2 then
		return true
	end

	if arg_0_mod_4 then
		return array.find(arg_0_mod_4.perks, var_0_mod_2) ~= nil
	end

	if ProgressionSettings.can_use(var_0_mod_2, "perks", arg_0_mod_5) or DlcSettings.can_use(var_0_mod_2, arg_0_mod_6) then
		return true
	end

	for iter_0_mod_0, iter_0_mod_1 in ipairs(arg_0_mod_7) do
		if iter_0_mod_1 == var_0_mod_2 then
			return true
		end
	end

	return false
end

local function var_0_mod_has_item(arg_0_mod_8, arg_0_mod_9)
	for iter_0_mod_2, iter_0_mod_3 in ipairs(arg_0_mod_8.groups) do
		for iter_0_mod_4, iter_0_mod_5 in ipairs(iter_0_mod_3.items) do
			if iter_0_mod_5.name == arg_0_mod_9 then
				return true
			end
		end
	end

	return false
end

local function var_0_mod_fitted_text(arg_0_mod_10, arg_0_mod_11, arg_0_mod_12, arg_0_mod_13, arg_0_mod_14, arg_0_mod_15)
	local var_0_mod_3 = arg_0_mod_15

	while var_0_mod_3 > 10 and arg_0_mod_13 < arg_0_mod_10:get_text_extents(arg_0_mod_11, nil, var_0_mod_3, true) do
		var_0_mod_3 = var_0_mod_3 - 1
	end

	arg_0_mod_10:text(arg_0_mod_11, arg_0_mod_12, arg_0_mod_14, nil, var_0_mod_3)
end

local function var_0_mod_icon_size(arg_0_mod_16)
	if string.find(arg_0_mod_16, "wepicon_", 1, true) == 1 then
		return Vector2(128, 56)
	end

	return Vector2(232, 60)
end

local M = {}

function M.setup_loadout(arg_3_0, arg_3_1)
	local var_3_0
	local var_3_1
	local var_3_2
	local var_3_3
	local var_3_4 = false

	if arg_3_0.parent.players[arg_3_1].player_go:owned() then
		local var_3_5 = arg_3_0.parent.players[arg_3_1].pad_number
		local var_3_6 = UserManager:get_user_id(var_3_5)

		var_3_0 = SaveManager:user_get("item_unlocks", var_3_6) or {}
		var_3_1 = SaveManager:user_get("new_unlocks", var_3_6) or {}
		var_3_3 = SaveManager:user_get("item_upgrades", var_3_6) or {}
		var_3_2 = DlcSettings.get_combined_entitlements(var_3_6)
		var_3_4 = true
	else
		var_3_0 = {}
		var_3_1 = {}
		var_3_2 = {}
		var_3_3 = {}
	end

	local var_3_7

	if arg_3_0.parent.players[arg_3_1].player_go:exists() then
		var_3_7 = arg_3_0.parent.players[arg_3_1].player_go:get("xp")
	else
		var_3_7 = 0
	end

	local var_3_8 = {
		available_items = {
			perks = {
				groups = {}
			},
			primary_weapon = {
				groups = {}
			},
			stratagems = {
				groups = {}
			},
			perk_slot = {
				groups = {}
			},
			sidearm_weapon = {
				groups = {}
			},
			grenade_slot = {
				groups = {}
			}
		},
		new_unlocks = var_3_1,
		item_upgrades = var_3_3,
		is_owned = var_3_4
	}

	var_3_8.loadout_hover_index_cursor = nil
	var_3_8.loadout_hover_index = 1
	var_3_8.last_current_selection_index = 1

	for iter_3_0, iter_3_1 in ipairs(LoadoutSettings.perks) do
		local var_3_9 = false

		if arg_3_0.specified_loadout then
			for iter_3_2, iter_3_3 in ipairs(arg_3_0.specified_loadout.perks) do
				if iter_3_3 == iter_3_1.name then
					var_3_9 = true
				end
			end
		else
			var_3_9 = ProgressionSettings.can_use(iter_3_1.name, "perks", var_3_7) or DlcSettings.can_use(iter_3_1.name, var_3_2)

			if not var_3_9 then
				for iter_3_4, iter_3_5 in ipairs(var_3_0) do
					if iter_3_1.name == iter_3_5 then
						var_3_9 = true

						break
					end
				end
			end
		end

		if var_3_9 and LoadoutSettings.is_equipment_perk(iter_3_1.name) then
			local var_3_10 = var_3_8.available_items.perks.groups
			local var_3_11 = iter_3_1.group or iter_3_1.name
			local var_3_12 = false

			for iter_3_6, iter_3_7 in ipairs(var_3_10) do
				if iter_3_7.name == var_3_11 then
					iter_3_7.items[#iter_3_7.items + 1] = iter_3_1
					var_3_12 = true

					break
				end
			end

			if not var_3_12 then
				local var_3_13 = {
					item_index = 1,
					name = var_3_11,
					items = {
						iter_3_1
					}
				}

				var_3_10[#var_3_10 + 1] = var_3_13
			end
		end
	end

	for iter_3_8, iter_3_9 in ipairs(LoadoutSettings.primary_weapon) do
		local var_3_14 = var_3_3[iter_3_9.name] or 0
		local var_3_15 = LoadoutSettings.get_upgraded_primary_weapon(iter_3_8, var_3_14)
		local var_3_16 = false

		if arg_3_0.specified_loadout then
			for iter_3_10, iter_3_11 in ipairs(arg_3_0.specified_loadout.primary_weapon) do
				if iter_3_11 == var_3_15.name then
					var_3_16 = true
				end
			end
		else
			var_3_16 = ProgressionSettings.can_use(var_3_15.name, "primary_weapon", var_3_7) or DlcSettings.can_use(var_3_15.name, var_3_2)

			if not var_3_16 then
				for iter_3_12, iter_3_13 in ipairs(var_3_0) do
					if var_3_15.name == iter_3_13 then
						var_3_16 = true

						break
					end
				end
			end
		end

		-- mod: the support weapons (flamethrower, chemthrower, 20mm cannon) are Proving Grounds
		-- weapons; vanilla lists them as primaries always. Only list them for a trial.
		if iter_3_9.group == "support" then
			var_3_16 = arg_3_0.is_proving_ground_trial or arg_3_0.specified_loadout ~= nil and var_3_16 or false
		end

		if var_3_16 then
			local var_3_17 = var_3_8.available_items.primary_weapon.groups
			local var_3_18 = var_3_15.group or var_3_15.name
			local var_3_19 = false

			for iter_3_14, iter_3_15 in ipairs(var_3_17) do
				if iter_3_15.name == var_3_18 then
					iter_3_15.items[#iter_3_15.items + 1] = var_3_15
					var_3_19 = true

					break
				end
			end

			if not var_3_19 then
				local var_3_20 = {
					item_index = 1,
					name = var_3_18,
					items = {
						var_3_15
					}
				}

				var_3_17[#var_3_17 + 1] = var_3_20
			end
		end
	end

	for iter_3_16, iter_3_17 in ipairs(LoadoutSettings.stratagems) do
		local var_3_21 = var_3_3[iter_3_17.name] or 0
		local var_3_22 = LoadoutSettings.get_upgraded_stratagem(iter_3_16, var_3_21)

		local var_3_23 = false

		if arg_3_0.specified_loadout then
			for iter_3_18, iter_3_19 in ipairs(arg_3_0.specified_loadout.stratagems) do
				if iter_3_19 == var_3_22.name then
					var_3_23 = true
				end
			end
		else
			var_3_23 = ProgressionSettings.can_use(var_3_22.name, "stratagems", var_3_7) or DlcSettings.can_use(var_3_22.name, var_3_2)

			if not var_3_23 then
				for iter_3_20, iter_3_21 in ipairs(var_3_0) do
					if var_3_22.name == iter_3_21 then
						var_3_23 = true

						break
					end
				end
			end
		end

		-- Mod: the four static stratagems (auto-added to slots 1-4) are never offered.
		if var_3_23 and not array.find(LoadoutSettings.static_stratagems, var_3_22.name) then
			local var_3_24 = var_3_8.available_items.stratagems.groups
			local var_3_25 = var_3_22.group or var_3_22.name
			local var_3_26 = false

			for iter_3_22, iter_3_23 in ipairs(var_3_24) do
				if iter_3_23.name == var_3_25 then
					iter_3_23.items[#iter_3_23.items + 1] = var_3_22
					var_3_26 = true

					break
				end
			end

			if not var_3_26 then
				local var_3_27 = {
					item_index = 1,
					name = var_3_25,
					items = {
						var_3_22
					}
				}

				var_3_24[#var_3_24 + 1] = var_3_27
			end
		end
	end

	for iter_3_mod_0, iter_3_mod_1 in ipairs(LoadoutSettings.loadout_slots) do
		if iter_3_mod_1.type ~= "perks" then
			local var_3_mod_0 = var_3_8.available_items[iter_3_mod_1.type].groups
			local var_3_mod_1 = LoadoutSettings[iter_3_mod_1.type]

			for iter_3_mod_2, iter_3_mod_3 in ipairs(var_3_mod_1) do
				if var_0_mod_slot_available(iter_3_mod_3, arg_3_0.specified_loadout, var_3_7, var_3_2, var_3_0) then
					var_3_mod_0[#var_3_mod_0 + 1] = {
						item_index = 1,
						name = iter_3_mod_3.name,
						items = {
							iter_3_mod_3
						}
					}
				end
			end
		end
	end

	local var_3_28
	local var_3_29

	if arg_3_0.parent.players[arg_3_1].player_go:owned() then
		arg_3_0.parent.players[arg_3_1].player_go:set("loadout_done", false)

		local var_3_30 = arg_3_0.parent.players[arg_3_1].pad_number
		local var_3_31 = UserManager:get_user_id(var_3_30)

		if IS_PS4 or var_3_30 == GameSettings.get_main_pad_number() then
			var_3_29 = SaveManager:user_get("loadouts", var_3_31)
			var_3_28 = SaveManager:user_get("loadout", var_3_31)
		else
			var_3_28 = SaveManager:get("loadout_" .. tostring(var_3_30))
			var_3_29 = SaveManager:get("loadouts_" .. tostring(var_3_30))
		end

		if var_3_29 == nil or #var_3_29 == 0 then
			var_3_29 = table.clone(LoadoutSettings.default_loadouts)

			if var_3_28 then
				var_3_29[1] = table.clone(var_3_28)
				var_3_29[2] = table.clone(var_3_28)
				var_3_29[3] = table.clone(var_3_28)
			end
		end

		var_3_28 = table.clone(var_3_29[1])

		for iter_3_24, iter_3_25 in ipairs(var_3_29) do
			iter_3_25 = Boot.ensure_loadout(var_3_31, iter_3_25 or table.clone(LoadoutSettings.default_loadout))
		end
	else
		var_3_29 = table.clone(LoadoutSettings.default_loadouts)
		var_3_28 = table.clone(var_3_29[1])
	end

	for iter_3_mod_4, iter_3_mod_5 in ipairs(var_3_29) do
		LoadoutSettings.migrate_loadout(iter_3_mod_5)
	end

	var_3_8.loadouts = var_3_29
	var_3_8.loadout_index = 1

	if arg_3_0.specified_loadout then
		var_3_28.perk = arg_3_0.specified_loadout.perks[1]
		var_3_28.primary_weapon = arg_3_0.specified_loadout.primary_weapon[1]

		local var_3_32 = 0

		for iter_3_26 = #LoadoutSettings.static_stratagems + 1, LoadoutSettings.nr_of_stratagem_slots do
			local var_3_33 = var_3_32 % #arg_3_0.specified_loadout.stratagems + 1

			var_3_28.stratagems[iter_3_26] = arg_3_0.specified_loadout.stratagems[var_3_33]
			var_3_32 = var_3_32 + 1
		end
	else
		for iter_3_27, iter_3_28 in ipairs(var_3_29) do
			local var_3_34 = false

			for iter_3_29, iter_3_30 in ipairs(var_3_8.available_items.primary_weapon.groups) do
				for iter_3_31, iter_3_32 in ipairs(iter_3_30.items) do
					if iter_3_28.primary_weapon == iter_3_32.name then
						var_3_34 = true

						break
					end
				end

				if var_3_34 then
					break
				end
			end

			local var_3_35 = false

			for iter_3_33, iter_3_34 in ipairs(var_3_8.available_items.perks.groups) do
				for iter_3_35, iter_3_36 in ipairs(iter_3_34.items) do
					if iter_3_28.perk == iter_3_36.name then
						var_3_35 = true

						break
					end
				end

				if var_3_35 then
					break
				end
			end

			local var_3_36 = true

			for iter_3_37, iter_3_38 in ipairs(iter_3_28.stratagems) do
				local var_3_37 = false

				if array.find(LoadoutSettings.static_stratagems, iter_3_38) then
					var_3_37 = iter_3_37 <= #LoadoutSettings.static_stratagems
				else
					for iter_3_39, iter_3_40 in ipairs(var_3_8.available_items.stratagems.groups) do
						for iter_3_41, iter_3_42 in ipairs(iter_3_40.items) do
							if iter_3_38 == iter_3_42.name then
								var_3_37 = true

								break
							end
						end

						if var_3_37 then
							break
						end
					end
				end

				if not var_3_37 then
					var_3_36 = false

					break
				end
			end

			for iter_3_mod_6, iter_3_mod_7 in ipairs(LoadoutSettings.loadout_slots) do
				if iter_3_mod_7.type ~= "perks" and not var_0_mod_has_item(var_3_8.available_items[iter_3_mod_7.type], iter_3_28[iter_3_mod_7.field]) then
					iter_3_28[iter_3_mod_7.field] = iter_3_mod_7.default
				end
			end

			if not var_3_34 or not var_3_35 or not var_3_36 then
				var_3_29[iter_3_27] = LoadoutSettings.migrate_loadout(table.clone(LoadoutSettings.default_loadout))
			end
		end
	end

	for iter_3_43, iter_3_44 in ipairs(var_3_29) do
		for iter_3_45, iter_3_46 in ipairs(LoadoutSettings.static_stratagems) do
			local var_3_38 = false

			for iter_3_47, iter_3_48 in ipairs(iter_3_44.stratagems) do
				if iter_3_46 == iter_3_48 then
					var_3_38 = true

					break
				end
			end

			if not var_3_38 then
				array.insert_at(iter_3_44.stratagems, #LoadoutSettings.static_stratagems - (iter_3_45 - 1), iter_3_46)

				while #iter_3_44.stratagems > LoadoutSettings.nr_of_stratagem_slots do
					iter_3_44.stratagems[#iter_3_44.stratagems] = nil
				end
			end
		end
	end

	local var_3_39 = table.clone(var_3_29[1])

	if arg_3_0.is_proving_ground_trial then
		var_3_39 = arg_3_0.proving_grounds_loadout
	end

	local var_3_40 = table.clone(LoadoutSettings.get_item("primary_weapon", var_3_39.primary_weapon))

	if var_3_39.primary_weapon and not var_3_40 then
		local var_3_41 = LoadoutSettings.get_item_by_unit_path("primary_weapon", var_3_39.primary_weapon).name

		var_3_40 = table.clone(LoadoutSettings.get_item("primary_weapon", var_3_41))
	end

	local var_3_mod_2 = {
		{
			right_index = 2,
			down_index = 3,
			up_index = 1
		},
		{
			left_index = 1,
			down_index = 4,
			up_index = 2
		},
		{
			right_index = 4,
			down_index = var_0_7,
			up_index = 1
		},
		{
			left_index = 3,
			down_index = var_0_7,
			up_index = 2
		}
	}

	var_3_8.loadout_menu = {}

	for iter_3_mod_8, iter_3_mod_9 in ipairs(LoadoutSettings.loadout_slots) do
		local var_3_mod_3 = var_3_mod_2[iter_3_mod_8]
		local var_3_mod_4 = LoadoutSettings.get_item(iter_3_mod_9.type, var_3_39[iter_3_mod_9.field] or iter_3_mod_9.default) or LoadoutSettings.get_item(iter_3_mod_9.type, iter_3_mod_9.default)

		var_3_8.loadout_menu[iter_3_mod_8] = {
			type = iter_3_mod_9.type,
			slot = iter_3_mod_9,
			item = table.clone(var_3_mod_4),
			up_index = var_3_mod_3.up_index,
			down_index = var_3_mod_3.down_index,
			left_index = var_3_mod_3.left_index,
			right_index = var_3_mod_3.right_index
		}
	end

	var_3_8.loadout_menu[var_0_7] = {
		type = "primary_weapon",
		item = var_3_40,
		up_index = 3
	}

	for iter_3_49 = #LoadoutSettings.static_stratagems + 1, LoadoutSettings.nr_of_stratagem_slots do
		if var_3_39.stratagems then
			array.insert_end(var_3_8.loadout_menu, {
				type = "stratagems",
				id = iter_3_49,
				item = table.clone(LoadoutSettings.get_item("stratagems", var_3_39.stratagems[iter_3_49])),
				up_index = var_0_7,
				down_index = var_0_7 + 5
			})
		end
	end

	array.insert_end(var_3_8.loadout_menu, {
		type = "button",
		up_index = var_0_7 + 1
	})

	var_3_8.enabled = true
	var_3_8.current_selection_index = 1
	var_3_8.selected_loadout_slot = 1
	var_3_8.confirm_loadout_blink = 0
	var_3_8.confirm_selection_blink = 0
	var_3_8.scroll_index_mouse = 1
	var_3_8.random_loadout = false
	var_3_8.cursor_selection_direction = nil

	if arg_3_0.is_proving_ground_trial then
		var_3_8.current_selection_index = #var_3_8.loadout_menu
	end

	arg_3_0.option_menus[arg_3_1] = var_3_8
end

function M.draw_menu(arg_6_0, arg_6_1, arg_6_2, arg_6_3, arg_6_4, arg_6_5, arg_6_6, arg_6_7, arg_6_8, arg_6_9, arg_6_10)
	arg_6_4:set_clip_region({
		10,
		100,
		arg_6_5 - 20,
		2000
	})
	arg_6_4:set_current_font("body_large")

	local var_6_0 = arg_6_10:get("index")
	local var_6_1 = arg_6_0.parent.players[var_6_0].pad_number
	local var_6_2 = arg_6_4.ui_scale

	if not arg_6_8.submenu then
		local var_6_3 = false
		local var_6_4 = false
		local var_6_5 = false

		for iter_6_0, iter_6_1 in ipairs(arg_6_8.new_unlocks) do
			if string.find(iter_6_1, "perk_") then
				var_6_3 = true
			elseif string.find(iter_6_1, "weapon_") then
				var_6_4 = true
			elseif string.find(iter_6_1, "stratagem_") then
				var_6_5 = true
			end
		end

		local var_6_6 = Vector3(-4, -2, 0)

		arg_6_2:set_clip_region()
		arg_6_2:set_current_font("body_large")
		arg_6_2:set_ignore_size_scale(true)

		local var_6_7, var_6_8, var_6_9 = arg_6_2:get_text_extents(tostring(arg_6_9.level))

		arg_6_2:set_ignore_size_scale(false)
		arg_6_2:text(tostring(arg_6_9.level), Vector3(2, arg_6_6 - var_6_8 - 6, arg_6_7 + 100), Color(255, 240, 175, 80))

		local var_6_10 = LocalizationManager:string(arg_6_9.title)

		arg_6_2:set_ignore_size_scale(true)

		local var_6_11 = arg_6_2:get_text_box_strings(var_6_10, 210)

		arg_6_2:set_ignore_size_scale(false)

		local var_6_12 = 0

		for iter_6_2, iter_6_3 in ipairs(var_6_11) do
			arg_6_2:text(iter_6_3, Vector3(2 + var_6_7, arg_6_6 - var_6_8 - 6 + var_6_12, arg_6_7 + 100))

			var_6_12 = var_6_12 - 16
		end

		local var_6_13 = 215

		arg_6_2:image("loadout_skull_01", Vector3(0, arg_6_6 - 140, arg_6_7 - 1), Vector2(232, 120), nil, Vector2(0, 0), Vector2(-1, 1))

		local var_6_14 = arg_6_8.loadout_menu
		local var_6_15
		local var_6_16
		local var_6_17
		local var_6_18 = Vector2(45, 40)
		local var_6_19 = arg_6_6 - 60
		local var_6_20 = LocalizationManager:string("loadout_favorites_title")

		arg_6_2:set_current_font("body_large")
		arg_6_2:text(var_6_20, Vector3(10, var_6_19, arg_6_7 + 11), Color(255, 178, 178, 178))

		local var_6_21 = var_6_19 - 50
		local var_6_22 = arg_6_5 - 235
		local var_6_23 = 60

		if arg_6_0.is_proving_ground_trial then
			arg_6_2:image("listbox_01", Vector3(5, var_6_21 - 5, arg_6_7 + 15), Vector2(arg_6_5 - 10, 51), Color(160, 255, 255, 255))
		else
			arg_6_2:image("listbox_01", Vector3(5, var_6_21 - 5, arg_6_7), Vector2(arg_6_5 - 10, 51), Color(160, 255, 255, 255))
		end

		local var_6_24 = Vector3(var_6_22, var_6_21, arg_6_7 + 11)

		if arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_24, var_6_18, var_6_1) then
			arg_6_8.loadout_hover_index_cursor = var_0_2
			var_6_16 = var_6_24
		end

		local var_6_25 = "loadout_fav_closed_01"

		if not arg_6_0.is_proving_ground_trial and arg_6_8.loadout_index == var_0_2 then
			var_6_17 = var_6_24
			var_6_25 = "loadout_fav_open_01"
		end

		arg_6_2:image(var_6_25, var_6_24, var_6_18, Color(255, 255, 255, 255))

		local var_6_26 = var_6_22 + var_6_23
		local var_6_27 = Vector3(var_6_26, var_6_21, arg_6_7 + 12)

		if arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_27, var_6_18, var_6_1) then
			arg_6_8.loadout_hover_index_cursor = var_0_3
			var_6_16 = var_6_27
		end

		local var_6_28 = "loadout_fav_closed_02"

		if arg_6_8.loadout_index == var_0_3 then
			var_6_17 = var_6_27
			var_6_28 = "loadout_fav_open_02"
		end

		arg_6_2:image(var_6_28, var_6_27, var_6_18, Color(255, 255, 255, 255))

		local var_6_29 = var_6_26 + var_6_23
		local var_6_30 = Vector3(var_6_29, var_6_21, arg_6_7 + 13)

		if arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_30, var_6_18, var_6_1) then
			arg_6_8.loadout_hover_index_cursor = var_0_4
			var_6_16 = var_6_30
		end

		local var_6_31 = "loadout_fav_closed_03"

		if arg_6_8.loadout_index == var_0_4 then
			var_6_17 = var_6_30
			var_6_31 = "loadout_fav_open_03"
		end

		arg_6_2:image(var_6_31, var_6_30, var_6_18, Color(255, 255, 255, 255))

		local var_6_32 = var_6_29 + var_6_23
		local var_6_33 = Vector3(var_6_32, var_6_21, arg_6_7 + 10)

		if arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_33, var_6_18, var_6_1) then
			arg_6_8.loadout_hover_index_cursor = var_0_5
			var_6_16 = var_6_33
		end

		local var_6_34 = "loadout_random_unselected"

		if arg_6_8.loadout_index == var_0_5 then
			var_6_17 = var_6_33
			var_6_34 = "loadout_random_selected"
		end

		arg_6_2:image(var_6_34, var_6_33, var_6_18, Color(255, 255, 255, 255))

		local var_6_36 = LocalizationManager:string("loadout_perk_title")
		local var_6_40 = var_6_21 - 25

		arg_6_2:set_current_font("body_large")
		arg_6_2:text(var_6_36, Vector3(10, var_6_40, arg_6_7 + 11), Color(255, 178, 178, 178))

		if var_6_3 and not arg_6_0.is_proving_ground_trial then
			arg_6_2:image("icon_new", Vector3(arg_6_5 - 16, var_6_40, arg_6_7 + 11) + var_6_6, Vector2(16, 16), Color(255, 255, 255, 255))
		end

		-- Custom loadout mod: 2x2 grid of slots in place of the single perk box.
		local var_6_mod_0 = 4
		local var_6_mod_1 = (arg_6_5 - 10 - var_6_mod_0) / 2
		local var_6_mod_2 = (90 - var_6_mod_0) / 2
		local var_6_mod_3 = var_6_40 - 95
		local var_6_mod_4 = Vector2(var_6_mod_1, var_6_mod_2)

		arg_6_2:set_current_font("body")

		for iter_6_mod_0, iter_6_mod_1 in ipairs(LoadoutSettings.loadout_slots) do
			local var_6_mod_5 = arg_6_8.loadout_menu[iter_6_mod_0]
			local var_6_mod_6 = (iter_6_mod_0 - 1) % 2
			local var_6_mod_7 = iter_6_mod_0 <= 2 and var_6_mod_2 + var_6_mod_0 or 0
			local var_6_mod_8 = Vector3(5 + var_6_mod_6 * (var_6_mod_1 + var_6_mod_0), var_6_mod_3 + var_6_mod_7, arg_6_7)
			local var_6_mod_9 = var_6_mod_5.item

			var_6_mod_5.box_size = var_6_mod_4

			arg_6_2:image("listbox_01", var_6_mod_8, var_6_mod_4, Color(120, 255, 255, 255))
			arg_6_2:text(var_0_mod_loc(iter_6_mod_1.title), var_6_mod_8 + Vector3(6, var_6_mod_2 - 15, 2), Color(255, 178, 178, 178), nil, 14)

			if not arg_6_8.random_loadout then
				local var_6_mod_10

				if iter_6_mod_1.type ~= "perks" and not arg_6_10:owned() then
					var_6_mod_10 = "-"
				else
					var_6_mod_10 = var_0_mod_item_name(var_6_mod_9)

					if var_6_mod_9 and var_6_mod_9.icon then
						local var_6_mod_11 = var_0_mod_icon_size(var_6_mod_9.icon)
						local var_6_mod_12 = math.min((var_6_mod_1 - 8) / var_6_mod_11.x, (var_6_mod_2 - 4) / var_6_mod_11.y)
						local var_6_mod_13 = Vector2(var_6_mod_11.x * var_6_mod_12, var_6_mod_11.y * var_6_mod_12)

						arg_6_2:image(var_6_mod_9.icon, var_6_mod_8 + Vector3(var_6_mod_1 - var_6_mod_13.x - 4, (var_6_mod_2 - var_6_mod_13.y) / 2, 1), var_6_mod_13, Color(70, 255, 255, 255))
					end
				end

				var_0_mod_fitted_text(arg_6_2, var_6_mod_10, var_6_mod_8 + Vector3(6, 6, 3), var_6_mod_1 - 12, Color(255, 255, 255, 255), 18)
			end

			if arg_6_8.current_selection_index == iter_6_mod_0 then
				var_6_15 = var_6_mod_8
			end

			if not arg_6_0.is_proving_ground_trial and arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_mod_8, var_6_mod_4, var_6_1) then
				arg_6_8.current_selection_index_cursor = iter_6_mod_0
			end
		end

		if arg_6_8.random_loadout then
			arg_6_2:image("loadout_random_primary", Vector3(arg_6_5 / 2 - 80, var_6_40 - 85, arg_6_7 + 4), Vector2(160, 56))
			arg_6_0:draw_selection_scroll_hd_gui(arg_6_4, arg_6_7 + 5, Vector3(10, var_6_40 - 25, 0), LocalizationManager:string("random_loadout"), (arg_6_5 - 30) * var_6_2, arg_6_8.current_selection_index < var_0_7, arg_6_1)
		end

		arg_6_2:set_current_font("body_large")

		if arg_6_0.is_proving_ground_trial then
			arg_6_2:image("icon_lock_big", Vector3(var_6_13, var_6_40 - 30, arg_6_7 + 11), Vector2(30, 30), Color(255, 255, 255, 255))
			arg_6_2:image("listbox_01", Vector3(5, var_6_40 - 95, arg_6_7 + 10), Vector2(arg_6_5 - 10, 90), Color(120, 255, 255, 255))
		end

		local var_6_44 = LocalizationManager:string("loadout_primary_weapon_title")
		local var_6_45 = arg_6_8.loadout_menu[var_0_7].item
		local var_6_46
		local var_6_47
		local var_6_48

		if var_6_45 then
			var_6_46 = arg_6_8.item_upgrades[var_6_45.name] or arg_6_8.loadout_menu[var_0_7].upgrade_value or 0
			var_6_47 = LocalizationManager:string(var_6_45.name)
			var_6_48 = var_6_45.icon
		else
			var_6_46 = 0
			var_6_47 = LocalizationManager:string("no_primary")
		end

		local var_6_49 = Vector2(unpack(arg_6_0.primary_weapon_icon_size))
		local var_6_50 = Vector2(unpack(arg_6_0.upgrade_icon_size))
		local var_6_51 = var_6_40 - 115

		arg_6_2:set_current_font("body_large")
		arg_6_2:text(var_6_44, Vector3(10, var_6_51, arg_6_7 + 11), Color(255, 178, 178, 178))

		if var_6_4 and not arg_6_0.is_proving_ground_trial then
			arg_6_2:image("icon_new", Vector3(arg_6_5 - 16, var_6_51, arg_6_7 + 11) + var_6_6, Vector2(16, 16), Color(255, 255, 255, 255))
		end

		local var_6_52 = Vector3(5, var_6_51 - 95, arg_6_7)
		local var_6_53 = Vector2(arg_6_5 - 10, 90)

		if arg_6_8.random_loadout then
			arg_6_2:image("listbox_01", Vector3(5, var_6_51 - 95, arg_6_7), Vector2(arg_6_5 - 10, 90), Color(120, 255, 255, 255))
			arg_6_2:image("loadout_random_primary", Vector3(arg_6_5 / 2 - 80, var_6_51 - 90, arg_6_7 + 1), Vector2(160, 56))
			arg_6_0:draw_selection_scroll_hd_gui(arg_6_4, arg_6_7 + 2, Vector3(10, var_6_51 - 25, 0), LocalizationManager:string("random_loadout"), (arg_6_5 - 30) * var_6_2, arg_6_8.current_selection_index == var_0_7, arg_6_1)
		else
			arg_6_2:image("listbox_01", var_6_52, var_6_53, Color(120, 255, 255, 255))

			if var_6_48 then
				arg_6_2:image(var_6_48, Vector3(arg_6_5 / 2 - var_6_49.x / 2 - var_6_50.x, var_6_51 - 90, arg_6_7 + 1), var_6_49)
			end

			if var_6_45 and var_6_45.upgrades then
				for iter_6_4, iter_6_5 in ipairs(var_6_45.upgrades) do
					if BitAux.is_bit_set(var_6_46, iter_6_4) then
						arg_6_2:image(iter_6_5.upgrade_icon, Vector3(arg_6_5 - var_6_50.x - 10 - (iter_6_4 - 1) * (var_6_50.x + 2), var_6_51 - 90, arg_6_7 + 1), var_6_50)
					else
						arg_6_2:image("weapon_upgrade_empty_slot", Vector3(arg_6_5 - var_6_50.x - 10 - (iter_6_4 - 1) * (var_6_50.x + 2), var_6_51 - 90, arg_6_7 + 1), var_6_50)
					end
				end
			end

			arg_6_0:draw_selection_scroll_hd_gui(arg_6_4, arg_6_7 + 2, Vector3(10, var_6_51 - 25, 0), var_6_47, (arg_6_5 - 30) * var_6_2, arg_6_8.current_selection_index == var_0_7, arg_6_1)
		end

		if arg_6_0.is_proving_ground_trial then
			arg_6_2:image("icon_lock_big", Vector3(var_6_13, var_6_51 - 30, arg_6_7 + 11), Vector2(30, 30), Color(255, 255, 255, 255))
			arg_6_2:image("listbox_01", Vector3(5, var_6_51 - 95, arg_6_7 + 10), Vector2(arg_6_5 - 10, 90), Color(120, 255, 255, 255))
		end

		if arg_6_8.current_selection_index == var_0_7 then
			var_6_15 = var_6_52
		end

		if not arg_6_0.is_proving_ground_trial and arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_52, var_6_53, var_6_1) then
			arg_6_8.current_selection_index_cursor = var_0_7
		end

		local var_6_54 = LocalizationManager:string("loadout_stratagems_title")
		local var_6_55 = var_6_51 - 115
		local var_6_56 = 10
		local var_6_57 = 10

		arg_6_2:set_current_font("body_large")
		arg_6_2:text(var_6_54, Vector3(10, var_6_55, arg_6_7 + 11), Color(255, 178, 178, 178))

		if var_6_5 and not arg_6_0.is_proving_ground_trial then
			arg_6_2:image("icon_new", Vector3(arg_6_5 - 16, var_6_55, arg_6_7 + 11) + var_6_6, Vector2(16, 16), Color(255, 255, 255, 255))
		end

		for iter_6_6, iter_6_7 in ipairs(var_6_14) do
			if iter_6_7.type == "stratagems" then
				local var_6_58 = iter_6_7.item
				local var_6_59

				if var_6_58 then
					var_6_59 = arg_6_8.item_upgrades[var_6_58.name] or iter_6_7.upgrade_value or 0
				else
					var_6_59 = 0
				end

				local var_6_60 = Vector2(unpack(arg_6_0.stratagem_icon_size))

				if arg_6_8.random_loadout then
					arg_6_2:image("loadout_random", Vector3(var_6_57, var_6_55 - 60, arg_6_7 + 10), var_6_60)
				elseif var_6_58 then
					MenuScreenBase:draw_stratagem_icon(nil, arg_6_2, var_6_58, var_6_59, Vector3(var_6_57, var_6_55 - 60, arg_6_7 + 10), var_6_60)
				end

				if arg_6_0.is_proving_ground_trial then
					arg_6_2:image("listbox_01", Vector3(var_6_57, var_6_55 - 60, arg_6_7 + 11), var_6_60, Color(125, 255, 255, 255))
					arg_6_2:image("icon_lock_small", Vector3(var_6_57 + 31, var_6_55 - 29, arg_6_7 + 12), Vector2(20, 20), Color(255, 255, 255, 255))
				end

				local var_6_61 = Vector3(var_6_57 - 4, var_6_55 - 64, arg_6_7)
				local var_6_62 = Vector2(58, 58)

				if arg_6_8.current_selection_index == iter_6_6 then
					var_6_15 = var_6_61
				end

				if not arg_6_0.is_proving_ground_trial and arg_6_8.is_owned and arg_6_8.enabled and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_61, var_6_62, var_6_1) then
					arg_6_8.current_selection_index_cursor = iter_6_6
				end

				var_6_57 = var_6_57 + var_6_60.x + var_6_56
			end
		end

		arg_6_2:image("listbox_01", Vector3(5, var_6_55 - 65, arg_6_7), Vector2(arg_6_5 - 10, 60), Color(120, 255, 255, 255))
		arg_6_2:set_current_font("body_large")

		if arg_6_8.enabled then
			local var_6_63

			if arg_6_10:owned() then
				var_6_63 = LocalizationManager:string("loadout_confirm_loadout")
			else
				var_6_63 = LocalizationManager:string("loadout_client_loadout_in_progress")
			end

			local var_6_64 = arg_6_2:get_text_extents(var_6_63, nil, nil, true)

			arg_6_2:text(var_6_63, Vector3(arg_6_5 / 2 - var_6_64 / 2, var_6_55 - 92, arg_6_7 + 100))
		else
			local var_6_65

			if arg_6_10:owned() then
				var_6_65 = LocalizationManager:string("loadout_change_loadout")
			else
				var_6_65 = LocalizationManager:string("loadout_client_loadout_done")
			end

			local var_6_66 = arg_6_2:get_text_extents(var_6_65, nil, nil, true)

			arg_6_2:text(var_6_65, Vector3(arg_6_5 / 2 - var_6_66 / 2, var_6_55 - 92, arg_6_7 + 100))
			arg_6_2:rect(Vector3(0, 0, arg_6_7 + 100), Vector2(arg_6_5, arg_6_6 + 30), Color(150, 0, 0, 0))
		end

		arg_6_2:image("listbox_01", Vector3(5, var_6_55 - 100, arg_6_7), Vector2(arg_6_5 - 10, 30), Color(120, 255, 255, 255))
		arg_6_2:rect(Vector3(0, 0, arg_6_7 + 91), Vector2(arg_6_5, arg_6_6 + 20), Color(100 * arg_6_8.confirm_loadout_blink, 200, 200, 200))

		local var_6_67 = Vector3(5, var_6_55 - 100, arg_6_7)
		local var_6_68 = Vector2(arg_6_5 - 10, 30)
		local var_6_69 = var_6_67

		if arg_6_8.current_selection_index == #var_6_14 then
			var_6_15 = var_6_67
		end

		if arg_6_8.is_owned and MenuScreenBase.is_box_selected_by_cursor(arg_6_0, arg_6_2, var_6_67, var_6_68, var_6_1) then
			arg_6_8.current_selection_index_cursor = #var_6_14
		end

		local var_6_70 = arg_6_0.parent.selection_blink
		local var_6_71 = arg_6_0.parent.selection_outline_blink
		local var_6_72 = var_6_14[arg_6_8.current_selection_index or 1]

		if var_6_72 == nil then
			return
		end

		local var_6_73
		local var_6_74
		local var_6_75

		if var_6_72.box_size then
			var_6_73 = var_6_72.box_size
			var_6_74 = "selectionbox_01"
			var_6_75 = Color(200 - 80 * var_6_70, 255, 255, 255)
		elseif var_6_72.type == "primary_weapon" then
			var_6_73 = Vector2(arg_6_5 - 10, 90)
			var_6_74 = "selectionbox_01"
			var_6_75 = Color(200 - 80 * var_6_70, 255, 255, 255)
		elseif var_6_72.type == "stratagems" then
			var_6_73 = Vector2(58, 58)
			var_6_74 = "selectionbox_outline_01"
			var_6_75 = Color(255 - 120 * var_6_71, 255, 255, 255)
		elseif var_6_72.type == "button" then
			var_6_73 = Vector2(arg_6_5 - 10, 30)
			var_6_74 = "selectionbox_01"
			var_6_75 = Color(200 - 80 * var_6_70, 255, 255, 255)
		elseif var_6_72.type == "radio_button" then
			var_6_73 = Vector2(25, 25)
			var_6_74 = "selectionbox_outline_01"
			var_6_75 = Color(255 - 120 * var_6_71, 255, 255, 255)
		end

		if not arg_6_0.is_proving_ground_trial then
			arg_6_2:image(var_6_74, var_6_15, var_6_73, var_6_75)
			arg_6_2:rect(var_6_15 + Vector3(0, 0, 100), var_6_73, Color(200 * arg_6_8.confirm_selection_blink, 200, 200, 200))

			local var_6_76 = var_6_17 - Vector2(6, 4, 2)
			local var_6_77 = var_6_18 + Vector2(11, 9)

			arg_6_2:image("selectionbox_outline_01", var_6_76, var_6_77, Color(255 - 120 * var_6_71, 255, 255, 255))
			arg_6_2:rect(var_6_76 + Vector3(0, 0, 100), var_6_77, Color(50, 200, 200, 200))

			if arg_6_8.loadout_hover_index_cursor and var_6_16 then
				local var_6_78 = var_6_16 + Vector3(0, 0, 100)
				local var_6_79 = var_6_18

				arg_6_2:image("selectionbox_outline_01", var_6_78, var_6_79, Color(255 - 120 * var_6_71, 255, 255, 255))
				arg_6_2:rect(var_6_78, var_6_79, Color(50, 200, 200, 200))
			end
		else
			arg_6_2:image("selectionbox_01", Vector3(5, 5, 999), Vector3(238, 30, 0), Color(200 - 80 * var_6_70, 255, 255, 255))
			arg_6_2:rect(Vector3(5, 5, 1000), Vector3(238, 30, 0), Color(200 * arg_6_8.confirm_selection_blink, 200, 200, 200))
		end
	elseif LoadoutSettings.get_loadout_slot(arg_6_8.submenu) then
		arg_6_0:draw_perks(arg_6_1, arg_6_2, arg_6_3, arg_6_5, arg_6_6, arg_6_7, arg_6_8, var_6_1)
	elseif arg_6_8.submenu == "primary_weapon" then
		arg_6_0:draw_primary_weapon(arg_6_1, arg_6_2, arg_6_3, arg_6_5, arg_6_6, arg_6_7, arg_6_8, var_6_1)
	elseif arg_6_8.submenu == "stratagems" then
		arg_6_0:draw_stratagems(arg_6_1, arg_6_2, arg_6_3, arg_6_5, arg_6_6, arg_6_7, arg_6_8, var_6_1)
	end

	arg_6_0:validate_scroll()
end

function M.draw_perks(arg_7_0, arg_7_1, arg_7_2, arg_7_3, arg_7_4, arg_7_5, arg_7_6, arg_7_7, arg_7_8)
	local var_7_mod_0 = arg_7_7.available_items[arg_7_7.submenu].groups
	local var_7_mod_1 = LoadoutSettings.get_loadout_slot(arg_7_7.submenu)
	local var_7_0 = false

	for iter_7_0, iter_7_1 in ipairs(arg_7_7.new_unlocks) do
		if string.find(iter_7_1, "perk_") then
			var_7_0 = true
		end
	end

	local var_7_1 = Vector2(0, 200)
	local var_7_2 = Vector2(arg_7_4, 220)

	arg_7_2:set_clip_region({
		var_7_1.x,
		var_7_1.y,
		var_7_2.x,
		var_7_2.y
	})

	local var_7_3 = var_0_mod_loc(var_7_mod_1.title)
	local var_7_4 = Vector2(unpack(arg_7_0.perk_icon_size))

	arg_7_2:set_current_font("body_large")
	arg_7_2:text(var_7_3, Vector3(10, arg_7_5 - 34, arg_7_6), Color(255, 200, 200, 200))

	if var_7_0 then
		arg_7_2:image("icon_new", Vector3(arg_7_4 - 16 - 10, arg_7_5 - 36, arg_7_6 + 11), Vector2(16, 16), Color(255, 255, 255, 255))
	end

	arg_7_2:set_current_font("body_large")

	local var_7_5 = var_7_4.y + 10
	local var_7_6 = arg_7_7.current_selection_index - 1

	if arg_7_8 == _G.KEYBOARD_MOUSE_PAD_NUMBER then
		if arg_7_7.y_scroll_input_mouse and (arg_7_0.force_scroll_items or MenuScreenBase.is_box_selected_by_cursor(arg_7_0, arg_7_2, var_7_1, var_7_2, arg_7_8)) then
			arg_7_7.scroll_index_mouse = arg_7_7.scroll_index_mouse + arg_7_7.y_scroll_input_mouse
			arg_7_7.scroll_index_mouse = math.clamp(arg_7_7.scroll_index_mouse, 1, math.max(#var_7_mod_0 - 2, 1))
			arg_7_7.y_scroll_input_mouse = nil
		end

		var_7_6 = arg_7_7.scroll_index_mouse
	end

	local var_7_7 = math.clamp(var_7_6, 1, math.max(#var_7_mod_0 - 2, 1))
	local var_7_8 = arg_7_5 - 160 + math.max(var_7_5 * math.min(var_7_7, #var_7_mod_0), var_7_5)
	local var_7_9
	local var_7_10

	for iter_7_2, iter_7_3 in ipairs(var_7_mod_0) do
		local var_7_11 = iter_7_3.items[1]

		if var_7_11.icon then
			local var_7_mod_2 = var_0_mod_icon_size(var_7_11.icon)

			arg_7_2:image(var_7_11.icon, Vector3(arg_7_4 / 2 - var_7_mod_2.x / 2, var_7_8 - var_7_mod_2.y / 2, arg_7_6), var_7_mod_2)
		else
			local var_7_mod_3 = var_0_mod_item_name(var_7_11)
			local var_7_mod_4 = arg_7_2:get_text_extents(var_7_mod_3, nil, nil, true)

			arg_7_2:text(var_7_mod_3, Vector3(arg_7_4 / 2 - var_7_mod_4 / 2, var_7_8 - 8, arg_7_6 + 1), Color(255, 255, 255, 255))
		end

		if var_7_0 then
			local var_7_12 = FontSettings.fonts.body_large.font_size

			if var_7_8 > 180 and var_7_8 < 360 then
				for iter_7_4, iter_7_5 in ipairs(arg_7_7.new_unlocks) do
					if iter_7_5 == var_7_11.name then
						arg_7_2:image("icon_new", Vector3(arg_7_4 - 16 - 10, var_7_8 + arg_7_0.perk_icon_size[2] / 2 - 16, arg_7_6 + 1), Vector2(16, 16), Color(255, 255, 255, 255))

						break
					end
				end
			end
		end

		local var_7_13 = Vector3(10, var_7_8 - arg_7_0.perk_icon_size[2] / 2, arg_7_6)
		local var_7_14 = Vector2(arg_7_4 - 20, 60)
		local var_7_15 = iter_7_2 == arg_7_7.current_selection_index

		if var_7_15 then
			var_7_9 = iter_7_3

			local var_7_16 = arg_7_0.parent.selection_blink

			arg_7_2:image("selectionbox_01", var_7_13, var_7_14, Color(200 - 80 * var_7_16, 255, 255, 255))
			arg_7_2:rect(var_7_13 + Vector3(0, 0, 100), var_7_14, Color(200 * arg_7_7.confirm_selection_blink, 200, 200, 200))
		end

		if var_7_7 <= iter_7_2 and iter_7_2 <= var_7_7 + 2 and MenuScreenBase.is_box_selected_by_cursor(arg_7_0, arg_7_2, var_7_13, var_7_14, arg_7_8) then
			var_7_10 = iter_7_3

			local var_7_17 = arg_7_0.parent.selection_blink

			arg_7_7.current_selection_index_cursor = iter_7_2

			if not var_7_15 then
				arg_7_2:image("selectionbox_mouseover_01", var_7_13, var_7_14, Color(100 - 40 * var_7_17, 255, 255, 255))
			end
		end

		arg_7_2:image("listbox_01", Vector3(10, var_7_8 - arg_7_0.perk_icon_size[2] / 2, arg_7_6 - 1), Vector2(arg_7_4 - 20, 60), Color(120, 255, 255, 255))

		var_7_8 = var_7_8 - var_7_5
	end

	var_7_9 = var_7_10 or var_7_9

	arg_7_0:draw_description(arg_7_1, arg_7_2, arg_7_3, arg_7_4, arg_7_5, arg_7_6, var_7_9.items[1].loc_name or var_7_9.items[1].name, var_0_mod_item_description(var_7_9.items[1]), var_7_9.items[1].attributes, var_7_9.items[1].upgrade_attributes, nil, nil, arg_7_7, nil, arg_7_8)

	local var_7_18 = #var_7_mod_0 > 3

	arg_7_0:draw_arrows(arg_7_2, arg_7_4, arg_7_5, arg_7_6, var_7_18 and var_7_7 > 1, var_7_18 and var_7_7 < math.max(#var_7_mod_0 - 2, 1), -4, arg_7_8, arg_7_7.current_selection_index_cursor ~= nil)
end

function M.draw_description(arg_10_0, arg_10_1, arg_10_2, arg_10_3, arg_10_4, arg_10_5, arg_10_6, arg_10_7, arg_10_8, arg_10_9, arg_10_10, arg_10_11, arg_10_12, arg_10_13, arg_10_14, arg_10_15)
	arg_10_7 = var_0_mod_loc(arg_10_7)
	arg_10_8 = var_0_mod_loc(arg_10_8)

	arg_10_3:set_current_font("body_large")

	local var_10_0 = FontSettings.fonts.body_large.font_size
	local var_10_1 = 146
	local var_10_2 = var_10_1
	local var_10_3 = 0
	local var_10_4 = Vector2(0, 10)
	local var_10_5 = Vector2(arg_10_4, var_10_2 + 8)
	local var_10_6 = var_10_2 + arg_10_13.y_scroll_offset

	arg_10_3:set_clip_region({
		var_10_4.x,
		var_10_4.y,
		var_10_5.x,
		var_10_5.y
	})
	arg_10_3:set_ignore_size_scale(true)

	local var_10_7 = arg_10_3:get_text_box_height(arg_10_7, arg_10_4 - 20)

	arg_10_3:set_ignore_size_scale(false)
	arg_10_3:text_box(arg_10_7, Vector3(10, var_10_6, arg_10_6), arg_10_4 - 20)

	local var_10_8 = var_10_6 - var_10_7 + 2
	local var_10_9 = var_10_3 + var_10_7 - 2

	arg_10_3:set_current_font("body")

	local var_10_10 = FontSettings.fonts.body.font_size
	local var_10_11 = Color(255, 250, 185, 90)

	if arg_10_12 and arg_10_12 == 1 then
		local var_10_12 = LocalizationManager:string("one_use")
		local var_10_13, var_10_14, var_10_15 = arg_10_3:get_text_extents(var_10_12)

		arg_10_3:text(var_10_12, Vector3(10, var_10_8, arg_10_6), var_10_11)

		var_10_8 = var_10_8 - var_10_10
		var_10_9 = var_10_9 + var_10_10
	elseif arg_10_11 then
		local var_10_16

		if arg_10_11 > 0 then
			local var_10_17 = string.format("%s %d %s", LocalizationManager:string("loadout_cooldown"), arg_10_11, LocalizationManager:string("loadout_seconds"))
			local var_10_18, var_10_19, var_10_20 = arg_10_3:get_text_extents(var_10_17)

			arg_10_3:text(var_10_17, Vector3(10, var_10_8, arg_10_6), var_10_11)

			var_10_8 = var_10_8 - var_10_10
			var_10_9 = var_10_9 + var_10_10
		end

		if arg_10_12 then
			local var_10_21 = string.format("%s %d", LocalizationManager:string("num_uses"), arg_10_12)
			local var_10_22, var_10_23, var_10_24 = arg_10_3:get_text_extents(var_10_21)

			arg_10_3:text(var_10_21, Vector3(10, var_10_8, arg_10_6), var_10_11)

			var_10_8 = var_10_8 - var_10_10
			var_10_9 = var_10_9 + var_10_10
		end
	end

	if arg_10_14 then
		local var_10_25 = LocalizationManager:string_format("activation_time", "#TIME", string.format("%.1f", arg_10_14))

		arg_10_3:text(var_10_25, Vector3(10, var_10_8, arg_10_6), var_10_11)

		var_10_8 = var_10_8 - var_10_10
		var_10_9 = var_10_9 + var_10_10
	end

	local var_10_26 = var_10_8 - 4
	local var_10_27 = var_10_9 + 4

	if arg_10_9 then
		local var_10_28 = IS_PSVITA and 1 or 0.75
		local var_10_29 = "weapon_stats_bar"
		local var_10_30 = Vector2(102 * var_10_28, 13)

		for iter_10_0, iter_10_1 in ipairs(LoadoutSettings.ATTRIBUTE_SORT_ORDER) do
			local var_10_31 = arg_10_9[iter_10_1]

			if var_10_31 then
				local var_10_32 = type(var_10_31) == "boolean" and var_10_11 or Color(255, 255, 255, 255)
				local var_10_33 = LocalizationManager:string(iter_10_1)

				arg_10_3:text(var_10_33, Vector3(10, var_10_26, arg_10_6), var_10_32)

				local var_10_34 = type(var_10_31)

				if var_10_34 == "string" then
					local var_10_35 = LocalizationManager:string(var_10_31)
					local var_10_36, var_10_37, var_10_38 = arg_10_3:get_text_extents(var_10_35)
					local var_10_39 = arg_10_4 - 10 - var_10_38.x

					if IS_PSVITA then
						var_10_39 = 10
						var_10_26 = var_10_26 - var_10_10
						var_10_27 = var_10_27 + var_10_10
					end

					arg_10_3:text(var_10_35, Vector3(var_10_39, var_10_26, arg_10_6))
				elseif var_10_34 == "number" then
					local var_10_40 = arg_10_4 - 10 - var_10_30.x

					if IS_PSVITA then
						var_10_40 = 10
						var_10_26 = var_10_26 - var_10_10
						var_10_27 = var_10_27 + var_10_10
					end

					arg_10_3:image(var_10_29, Vector3(var_10_40, var_10_26, arg_10_6), var_10_30, nil, Vector2(0, 0), Vector2(1, 0.3333333333333333))

					local var_10_41 = var_10_31 / LoadoutSettings.WEAPON_ATTRIBUTES_VISUALIZATION_STEPS

					arg_10_3:image(var_10_29, Vector3(var_10_40, var_10_26, arg_10_6), Vector2(var_10_30.x * var_10_41, var_10_30.y), nil, Vector2(0, 0.3333333333333333), Vector2(var_10_41, 0.6666666666666666))

					if arg_10_10 and arg_10_10[iter_10_1] then
						local var_10_42 = (arg_10_10[iter_10_1] - var_10_31) / LoadoutSettings.WEAPON_ATTRIBUTES_VISUALIZATION_STEPS

						arg_10_3:image(var_10_29, Vector3(var_10_40 + var_10_30.x * var_10_41, var_10_26, arg_10_6), Vector2(var_10_30.x * var_10_42, var_10_30.y), nil, Vector2(var_10_41, 0.6666666666666666), Vector2(var_10_41 + var_10_42, 1))
					end
				elseif var_10_34 == "boolean" then
					-- block empty
				end

				var_10_26 = var_10_26 - var_10_10
				var_10_27 = var_10_27 + var_10_10
			end
		end

		var_10_26 = var_10_26 - 4
		var_10_27 = var_10_27 + 4
	end

	arg_10_3:set_current_font("body")
	arg_10_3:set_ignore_size_scale(true)

	local var_10_43 = arg_10_3:get_text_box_height(arg_10_8, arg_10_4 - 40)

	arg_10_3:set_ignore_size_scale(false)
	arg_10_3:text_box(arg_10_8, Vector3(10, var_10_26, arg_10_6), arg_10_4 - 40, Color(255, 178, 178, 178))

	local var_10_44 = var_10_27 + var_10_43

	if var_10_1 < var_10_44 then
		if arg_10_15 == _G.KEYBOARD_MOUSE_PAD_NUMBER then
			if arg_10_13.y_scroll_input_mouse and (arg_10_0.force_scroll_description or MenuScreenBase.is_box_selected_by_cursor(arg_10_0, arg_10_3, var_10_4, var_10_5, arg_10_15)) then
				arg_10_13.y_scroll_offset = arg_10_13.y_scroll_offset + arg_10_13.y_scroll_input_mouse * var_0_1
				arg_10_13.y_scroll_input_mouse = nil
			end
		else
			arg_10_13.y_scroll_offset = arg_10_13.y_scroll_offset - arg_10_13.y_scroll_input * REAL_TIME_DT * var_0_0
		end

		arg_10_13.y_scroll_offset = math.clamp(arg_10_13.y_scroll_offset, 0, var_10_44 - var_10_1)

		local var_10_45 = arg_10_4 - 20 - 12
		local var_10_46 = Vector2(32, 32)
		local var_10_47 = Color(255 - 100 * arg_10_0.arrow_blink, 255, 255, 255)

		if arg_10_13.y_scroll_offset > 0 then
			local var_10_48 = Vector3(var_10_45, var_10_1 - 10, arg_10_6 + 1)

			MenuScreenBase.check_and_draw_scroll_button(arg_10_0, arg_10_2, "scroll_up_description", var_10_48, var_10_46, math.rad(90), var_10_47, arg_10_15)
		end

		if arg_10_13.y_scroll_offset < var_10_44 - var_10_1 then
			local var_10_49 = Vector3(var_10_45 + 1, 1, arg_10_6 + 1)

			MenuScreenBase.check_and_draw_scroll_button(arg_10_0, arg_10_2, "scroll_down_description", var_10_49, var_10_46, math.rad(-90), var_10_47, arg_10_15)
		end
	end
end

function M.on_exit(arg_12_0)
	for iter_12_0, iter_12_1 in ipairs(arg_12_0.hd_gui) do
		iter_12_1:destroy()
	end

	SaveManager:set("use_proving_grounds_loadout", arg_12_0.is_proving_ground_trial)

	if arg_12_0.is_proving_ground_trial then
		SaveManager:set("proving_grounds_loadout", arg_12_0.proving_grounds_loadout)
	end

	for iter_12_2, iter_12_3 in ipairs(arg_12_0.option_menus) do
		if arg_12_0.parent.players[iter_12_2].player_go:owned() then
			local var_12_0 = arg_12_0.parent.players[iter_12_2].pad_number
			local var_12_1 = table.clone(LoadoutSettings.default_loadout)
			local var_12_2 = table.clone(LoadoutSettings.default_loadout)
			local var_12_3 = table.clone(LoadoutSettings.default_loadouts)
			local var_12_4 = iter_12_3.loadouts
			local var_12_5 = var_12_4[iter_12_3.loadout_index]

			if not arg_12_0.is_proving_ground_trial then
				for iter_12_4, iter_12_5 in ipairs(iter_12_3.loadout_menu) do
					if iter_12_5.item ~= nil then
						if arg_12_0.parent.menu_state == arg_12_0.parent.MENU_STATE_START_MISSION then
							local var_12_6 = array.find(iter_12_3.new_unlocks, iter_12_5.item.name)

							if var_12_6 then
								array.remove_at(iter_12_3.new_unlocks, var_12_6)
							end
						end

						if iter_12_3.loadout_index ~= var_0_5 then
							if iter_12_5.type == "stratagems" then
								var_12_4[iter_12_3.loadout_index].stratagems[iter_12_5.id] = iter_12_5.item.name
							elseif iter_12_5.slot then
								var_12_4[iter_12_3.loadout_index][iter_12_5.slot.field] = iter_12_5.item.name
							elseif iter_12_5.type == "primary_weapon" then
								var_12_4[iter_12_3.loadout_index].primary_weapon = iter_12_5.item.name
							else
								assert(false, "Invalid option type")
							end
						end
					end
				end
			end

			local var_12_7 = arg_12_0.parent.players[iter_12_2].player_go:get("using_random_loadout")

			if var_12_7 then
				local var_12_8 = iter_12_3.available_items.perks.groups[math.random(#iter_12_3.available_items.perks.groups)]

				var_12_2.perk = var_12_8.items[math.random(#var_12_8.items)].name

				local var_12_9 = iter_12_3.available_items.primary_weapon.groups[math.random(#iter_12_3.available_items.primary_weapon.groups)]

				var_12_2.primary_weapon = var_12_9.items[math.random(#var_12_9.items)].name

				for iter_12_mod_0, iter_12_mod_1 in ipairs(LoadoutSettings.loadout_slots) do
					local var_12_mod_0 = iter_12_3.available_items[iter_12_mod_1.type].groups

					if #var_12_mod_0 > 0 then
						local var_12_mod_1 = var_12_mod_0[math.random(#var_12_mod_0)]

						var_12_2[iter_12_mod_1.field] = var_12_mod_1.items[math.random(#var_12_mod_1.items)].name
					end
				end

				local var_12_10 = {}

				for iter_12_6, iter_12_7 in ipairs(iter_12_3.available_items.stratagems.groups) do
					for iter_12_8, iter_12_9 in ipairs(iter_12_7.items) do
						array.insert_at(var_12_10, iter_12_8, iter_12_9.name)
					end
				end

				for iter_12_10 = 5, 8 do
					local var_12_11 = math.random(#var_12_10)
					local var_12_12 = var_12_10[var_12_11]

					var_12_2.stratagems[iter_12_10] = var_12_12

					array.remove_at(var_12_10, var_12_11)
				end
			end

			if IS_PS4 or var_12_0 == GameSettings.get_main_pad_number() then
				local var_12_13 = UserManager:get_user_id(var_12_0)

				SaveManager:user_set("loadout", var_12_5, var_12_13)
				SaveManager:user_set("loadouts", var_12_4, var_12_13)
				SaveManager:user_set("new_unlocks", iter_12_3.new_unlocks, var_12_13)
				SaveManager:user_set("use_random_loadout", var_12_7, var_12_13)
				SaveManager:user_set("random_loadout", var_12_2, var_12_13)
			else
				SaveManager:set("loadout_" .. tostring(var_12_0), var_12_5)
				SaveManager:set("new_unlocks_" .. tostring(var_12_0), iter_12_3.new_unlocks)
				SaveManager:set("loadouts_" .. tostring(var_12_0), var_12_4)
				SaveManager:set("use_random_loadout_" .. tostring(var_12_0), var_12_7)
				SaveManager:set("random_loadout_" .. tostring(var_12_0), var_12_2)
			end
		end
	end

	local var_12_14 = arg_12_0.parent.world_proxy:viewport("menu_viewport")

	var_12_14:remove_shading_environment_variable("dof_near_setting")
	var_12_14:remove_shading_environment_variable("dof_far_setting")
end

function M.update_loadout_view(arg_16_0, arg_16_1, arg_16_2, arg_16_3)
	if arg_16_2 == arg_16_1.loadout_index or arg_16_1.enabled == false or arg_16_1.submenu then
		return
	end

	if arg_16_1.loadout_index ~= var_0_5 then
		local var_16_0 = arg_16_1.loadouts[arg_16_1.loadout_index]

		for iter_16_0, iter_16_1 in ipairs(arg_16_1.loadout_menu) do
			if iter_16_1.item ~= nil then
				if iter_16_1.type == "stratagems" then
					var_16_0.stratagems[iter_16_1.id] = iter_16_1.item.name
				elseif iter_16_1.slot then
					var_16_0[iter_16_1.slot.field] = iter_16_1.item.name
				elseif iter_16_1.type == "primary_weapon" then
					var_16_0.primary_weapon = iter_16_1.item.name
				else
					assert(false, "Invalid option type")
				end
			end
		end
	end

	arg_16_1.loadout_index = arg_16_2

	if arg_16_3 == nil or arg_16_3 == false then
		arg_16_0:play_sound_accept(nil, 1)
	end

	if arg_16_1.loadout_index == var_0_5 then
		arg_16_1.random_loadout = true

		if arg_16_0.shown_random_loadout_hint == false and arg_16_0.parent.hint_manager then
			arg_16_0.shown_random_loadout_hint = true

			arg_16_0.parent.hint_manager:add_hint("hint_random_loadout")
		end

		if arg_16_1.current_selection_index ~= #arg_16_1.loadout_menu then
			arg_16_1.last_current_selection_index = arg_16_1.current_selection_index
			arg_16_1.current_selection_index = #arg_16_1.loadout_menu
		end
	else
		if arg_16_1.random_loadout then
			arg_16_1.current_selection_index = arg_16_1.last_current_selection_index
		end

		arg_16_1.random_loadout = false

		local var_16_1 = arg_16_1.loadouts[arg_16_1.loadout_index]

		for iter_16_mod_0, iter_16_mod_1 in ipairs(LoadoutSettings.loadout_slots) do
			local var_16_mod_0 = LoadoutSettings.get_item(iter_16_mod_1.type, var_16_1[iter_16_mod_1.field] or iter_16_mod_1.default) or LoadoutSettings.get_item(iter_16_mod_1.type, iter_16_mod_1.default)

			arg_16_1.loadout_menu[var_0_6 + iter_16_mod_0 - 1].item = table.clone(var_16_mod_0)
		end

		arg_16_1.loadout_menu[var_0_7].item = table.clone(LoadoutSettings.get_item("primary_weapon", var_16_1.primary_weapon))

		for iter_16_2, iter_16_3 in ipairs(var_16_1.stratagems) do
			if iter_16_2 > 4 then
				local var_16_2 = table.clone(LoadoutSettings.get_item("stratagems", iter_16_3))

				arg_16_1.loadout_menu[var_0_7 + (iter_16_2 - 4)].item = var_16_2
			end
		end
	end
end

function M.update_selection(arg_17_0, arg_17_1, arg_17_2)
	local var_17_0 = arg_17_2.submenu and arg_17_2.available_items[arg_17_2.submenu].groups or arg_17_2.loadout_menu
	local var_17_1 = var_17_0[arg_17_2.current_selection_index]

	if arg_17_1.up or arg_17_1.down or arg_17_1.left or arg_17_1.right then
		arg_17_0:reset_description_scroll(arg_17_2)
	end

	if var_17_1 then
		if arg_17_1.up then
			if var_17_1.up_index then
				arg_17_2.current_selection_index = var_17_1.up_index
			elseif arg_17_2.submenu == "stratagems" then
				local var_17_2 = arg_17_2.current_selection_index - 3

				if var_17_0[var_17_2] then
					arg_17_2.current_selection_index = var_17_2
				end
			else
				arg_17_2.current_selection_index = math.max(arg_17_2.current_selection_index - 1, 1)
			end
		elseif arg_17_1.right then
			if var_17_1.right_index then
				arg_17_2.current_selection_index = var_17_1.right_index
			else
				if arg_17_2.submenu == "primary_weapon" then
					local var_17_3 = arg_17_2.available_items[arg_17_2.submenu].groups[arg_17_2.current_selection_index]

					var_17_3.item_index = math.min(var_17_3.item_index + 1, #var_17_3.items)
				end

				if arg_17_2.submenu == "stratagems" or arg_17_2.submenu == nil and arg_17_2.current_selection_index >= var_0_7 + 1 and arg_17_2.current_selection_index <= var_0_7 + 3 then
					arg_17_2.current_selection_index = math.min(arg_17_2.current_selection_index + 1, #var_17_0)
				end
			end
		elseif arg_17_1.down then
			if var_17_1.down_index then
				arg_17_2.current_selection_index = var_17_1.down_index
			elseif arg_17_2.submenu == "stratagems" then
				local var_17_4 = arg_17_2.current_selection_index + 3

				if var_17_0[var_17_4] then
					arg_17_2.current_selection_index = var_17_4
				end
			else
				arg_17_2.current_selection_index = math.min(arg_17_2.current_selection_index + 1, #var_17_0)
			end
		elseif arg_17_1.left then
			if var_17_1.left_index then
				arg_17_2.current_selection_index = var_17_1.left_index
			else
				if arg_17_2.submenu == "primary_weapon" then
					local var_17_5 = arg_17_2.available_items[arg_17_2.submenu].groups[arg_17_2.current_selection_index]

					var_17_5.item_index = math.max(var_17_5.item_index - 1, 1)
				end

				if arg_17_2.submenu == "stratagems" or arg_17_2.submenu == nil and arg_17_2.current_selection_index >= var_0_7 + 2 and arg_17_2.current_selection_index <= var_0_7 + 4 then
					arg_17_2.current_selection_index = math.max(arg_17_2.current_selection_index - 1, 1)
				end
			end
		end
	end
end

local var_0_mod_replaced = {
	"setup_loadout",
	"draw_menu",
	"draw_perks",
	"draw_description",
	"on_exit",
	"update_loadout_view",
	"update_selection"
}

-- Vanilla setup_loadout resets every saved favourite's sidearm to the pistol. With
-- the mod off for this screen, put the player's sidearm choices back afterwards so
-- they are still there in the next lobby that allows the mod.
local function var_0_mod_saved_sidearms(arg_3_0, arg_3_1)
	local var_3_mod_0 = arg_3_0.parent.players[arg_3_1]

	if not var_3_mod_0 or not var_3_mod_0.player_go:owned() then
		return nil
	end

	local var_3_30 = var_3_mod_0.pad_number
	local var_3_29

	if IS_PS4 or var_3_30 == GameSettings.get_main_pad_number() then
		var_3_29 = SaveManager:user_get("loadouts", UserManager:get_user_id(var_3_30))
	else
		var_3_29 = SaveManager:get("loadouts_" .. tostring(var_3_30))
	end

	if type(var_3_29) ~= "table" or #var_3_29 == 0 then
		return nil
	end

	local var_3_mod_1 = {}

	for iter_3_mod_0, iter_3_mod_1 in ipairs(var_3_29) do
		var_3_mod_1[iter_3_mod_0] = type(iter_3_mod_1) == "table" and iter_3_mod_1.sidearm_weapon or nil
	end

	return var_3_mod_1
end

local function patch_menu()
	local var_menu_0 = MenuScreenLoadout

	if var_menu_0.mod_custom_loadout then
		return
	end

	if not LoadoutSettings.loadout_slots then
		log("custom loadout %s: loadout settings are not patched, loadout menu left alone", CL.version)

		return
	end

	var_menu_0.mod_custom_loadout = true

	local var_menu_1 = {}

	for iter_menu_0, iter_menu_1 in ipairs(var_0_mod_replaced) do
		local var_menu_2 = var_menu_0[iter_menu_1]
		local var_menu_3 = M[iter_menu_1]

		var_menu_1[iter_menu_1] = var_menu_2

		var_menu_0[iter_menu_1] = function(arg_menu_0, ...)
			if arg_menu_0.mod_cl then
				return var_menu_3(arg_menu_0, ...)
			end

			return var_menu_2(arg_menu_0, ...)
		end
	end

	function var_menu_0.setup_loadout(arg_3_0, arg_3_1)
		if arg_3_0.mod_cl == nil then
			arg_3_0.mod_cl = CL.active()
		end

		if arg_3_0.mod_cl then
			return M.setup_loadout(arg_3_0, arg_3_1)
		end

		local var_3_mod_2 = var_0_mod_saved_sidearms(arg_3_0, arg_3_1)
		local var_3_mod_3 = var_menu_1.setup_loadout(arg_3_0, arg_3_1)
		local var_3_mod_4 = arg_3_0.option_menus and arg_3_0.option_menus[arg_3_1]

		if var_3_mod_2 and var_3_mod_4 and var_3_mod_4.loadouts then
			for iter_3_mod_2, iter_3_mod_3 in ipairs(var_3_mod_4.loadouts) do
				if var_3_mod_2[iter_3_mod_2] ~= nil and LoadoutSettings.get_item("sidearm_weapon", var_3_mod_2[iter_3_mod_2]) then
					iter_3_mod_3.sidearm_weapon = var_3_mod_2[iter_3_mod_2]
				end
			end
		end

		return var_3_mod_3
	end

	local var_menu_4 = var_menu_0.on_enter

	function var_menu_0.on_enter(arg_2_0, ...)
		arg_2_0.mod_cl = CL.active()

		local var_2_mod_0 = var_menu_4(arg_2_0, ...)

		-- The slot icons (sidearm weapon icons) must clip like the others.
		if arg_2_0.mod_cl then
			for iter_2_mod_0, iter_2_mod_1 in pairs(arg_2_0.hd_gui or {}) do
				for iter_2_mod_2, iter_2_mod_3 in ipairs(LoadoutSettings.sidearm_weapon) do
					if iter_2_mod_3.icon then
						iter_2_mod_1:add_clippable_materials(iter_2_mod_3.icon)
					end
				end
			end
		end

		log("custom loadout %s: loadout screen %s", CL.version, arg_2_0.mod_cl and "modded" or "vanilla (session mods off)")

		return var_2_mod_0
	end

	log("custom loadout %s: loadout menu patched", CL.version)
end

-- Run each patch when its script is first required (or now, if it already ran).
local var_0_mod_targets = {
	{
		"lua/settings/loadout_settings",
		"LoadoutSettings",
		patch_settings
	},
	{
		"lua/components/inventory_component",
		"InventoryComponent",
		patch_inventory
	},
	{
		"lua/menu/menu_screen_loadout",
		"MenuScreenLoadout",
		patch_menu
	}
}

for iter_0_mod_0, iter_0_mod_1 in ipairs(var_0_mod_targets) do
	local var_0_mod_name, var_0_mod_global, var_0_mod_patch = iter_0_mod_1[1], iter_0_mod_1[2], iter_0_mod_1[3]

	local function var_0_mod_run()
		if rawget(_G, var_0_mod_global) == nil then
			log("custom loadout %s: %s did not define %s", CL.version, var_0_mod_name, var_0_mod_global)

			return
		end

		local var_0_mod_ok, var_0_mod_err = pcall(var_0_mod_patch)

		if not var_0_mod_ok then
			log("custom loadout %s: patching %s failed: %s", CL.version, var_0_mod_name, tostring(var_0_mod_err))
		end
	end

	if rawget(_G, var_0_mod_global) ~= nil then
		var_0_mod_run()
	elseif CL.obsidian and CL.obsidian.on_require then
		CL.obsidian.on_require(var_0_mod_name, var_0_mod_run)
	end
end

log("custom loadout %s entry started", CL.version)

return {
	version = CL.version
}
