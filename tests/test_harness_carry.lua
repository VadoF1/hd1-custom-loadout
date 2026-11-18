-- Offline check of the Saber-while-carrying patch: runs the game's
-- CharacterStateCarry (decompiled source or bytecode) under the mod's entry
-- script with stubbed engine APIs, and simulates carry frames.
-- Usage: luajit test_harness_carry.lua <main.lua> <character_state_carry.lua>
local ENTRY, CARRY = arg[1], arg[2]

local function run(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("*a")
	f:close()
	if s:sub(1, 3) ~= "\27LJ" then s = s:gsub("^\239\187\191", "") end
	return assert(loadstring(s, "@" .. path))()
end

local fails, checks = 0, 0
local function check(cond, name)
	checks = checks + 1
	if cond then print("ok  " .. name) else fails = fails + 1 print("FAIL " .. name) end
end

-- engine stubs
local V = {}
V.__index = V
Vector3 = setmetatable({}, { __call = function(_, x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end })
Vector3.length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
Vector3.length_squared = function(v) return v.x * v.x + v.y * v.y + v.z * v.z end
Vector3Aux = { unbox = function(b) return Vector3(b[1], b[2], b[3]) end }

local alive = {}
local commands, anims = {}, {}
Unit = {
	alive = function(u) return u ~= nil and alive[u] == true end,
	flow_event = function(u, e) if e == "on_wielded" then anims[#anims + 1] = "flow:on_wielded" end end,
}

local components = {}
local melee_state = {}
local pending_melee = {}

EntityAux = {
	has_component = function(u, c) return components[u] and components[u][c] or false end,
	state = function(u, c) if c == "melee" then return melee_state[u] end end,
	state_master_interface = function() return { is_reloading = false, reloadable = false, num_mags = 0 } end,
	queue_command_master = function(u, c, cmd, arg)
		commands[#commands + 1] = { u, c, cmd }
		if c == "melee" and cmd == "melee" then pending_melee[#pending_melee + 1] = u end
	end,
	queue_command_master_interface = function(u, c, cmd, arg) commands[#commands + 1] = { u, c, cmd, arg } end,
}

CharacterStateMachine = {
	animation_event = function(u, e) anims[#anims + 1] = e end,
	change_state = function(u, ctx, s) ctx.state.new_state = s end,
}
CharacterStateIdle, CharacterStateTeleport, CharacterStateJump, CharacterStateDodge = {}, {}, {}, {}
InventoryComponent = { can_switch_weapon = function() return false end }

local session_on = true
local hooks = {}
_G.obsidian = {
	log = function() end,
	on_require = function(name, fn) hooks[name] = fn end,
	session = { cleared = function() return session_on end },
}

run(ENTRY)
check(hooks["lua/character_states/character_state_carry"] ~= nil, "entry waits for the carry script")
run(CARRY)
hooks["lua/character_states/character_state_carry"]()
check(CharacterStateCarry.mod_custom_loadout == true, "carry state patched")

local comp = {
	handle_health_status_change = function() return false end,
	handle_communication = function() end,
	queue_command_master = function() end,
}

local SABER, PISTOL, BOX, PLAYER = "saber", "pistol", "box", "player"
alive[SABER], alive[PISTOL], alive[BOX], alive[PLAYER] = true, true, true, true
components[SABER] = { meleeweapon = true, melee = true }
components[PISTOL] = { melee = true }
melee_state[SABER] = { melee_time = -1 }
melee_state[PISTOL] = { melee_time = -1 }

local function new_ctx(weapon)
	local input = { fire = false, fire_auto = false, melee = false, aim = { 0, 0, 0 } }
	return {
		settings = { character_info = { move_speed_jog = 5, move_speed_aim = 3 } },
		state = {
			input = input,
			current_weapon = weapon,
			current_carry_unit = BOX,
			mover_state = { velocity = { 0, 0, 0 } },
			inventory_state = { switch_weapon_time = 0 },
		},
	}
end

-- one frame: run the carry update, then let the melee component run queued commands
local DT = 1 / 30
local function frame(ctx)
	commands, anims = {}, {}
	CharacterStateCarry.update(PLAYER, ctx, DT, comp)
	for u, s in pairs(melee_state) do
		if s.melee_time >= 0 then s.melee_time = s.melee_time - DT end
	end
	for _, u in ipairs(pending_melee) do melee_state[u].melee_time = 0.33 end
	pending_melee = {}
end
local function count(cmd)
	local n = 0
	for _, c in ipairs(commands) do if c[3] == cmd then n = n + 1 end end
	return n
end
local function has_anim(e)
	for _, a in ipairs(anims) do if a == e then return true end end
	return false
end

-- Saber, session mods on
local ctx = new_ctx(SABER)
CharacterStateCarry.on_enter(PLAYER, ctx, CharacterStateIdle, comp)
frame(ctx)
check(count("melee") == 0 and count("firing_single") == 0, "no input: nothing happens")

ctx.state.input.fire, ctx.state.input.fire_auto = true, true
frame(ctx)
check(count("melee") == 1, "fire with Saber queues a melee swing")
check(count("firing_single") == 0, "fire with Saber is not sent as a gun shot")
check(not has_anim("aim"), "fire with Saber does not play the hold-out (aim) pose")
check(anims[1] == "no_animation_fullbody" and has_anim("no_animation") and has_anim("flow:on_wielded") and has_anim("idle_upper") and has_anim("idle_lower"), "swing leaves the carry pose first (" .. table.concat(anims, ",") .. ")")
check(not has_anim("carry_walk"), "no carry pose during the swing frame")
check(ctx.state.input.fire == true and ctx.state.input.fire_auto == true and ctx.state.input.melee == false, "input table restored after the frame")

local extra, extra_shots = 0, 0
for i = 1, 9 do frame(ctx) extra = extra + count("melee") extra_shots = extra_shots + count("firing_single") end
check(extra == 0 and extra_shots == 0, "held fire mid swing: no second swing, no shots")

ctx.state.input.fire, ctx.state.input.fire_auto = false, false
local restored = false
for i = 1, 6 do frame(ctx) if has_anim("carry_walk") then restored = has_anim("idle_lower") end end
check(restored, "swing over: carry pose restored (carry_walk + idle_lower)")
check(ctx.state.mod_cl_carry_swing == nil, "swing tracking cleared")

-- held fire repeats swings, like the normal Saber
ctx.state.input.fire, ctx.state.input.fire_auto = true, true
local swings, carry_between = 0, false
for i = 1, 40 do frame(ctx) swings = swings + count("melee") if has_anim("carry_walk") then carry_between = true end end
check(not carry_between, "held fire: no carry pose flicker between swings")
check(swings >= 3 and swings <= 4, "held fire keeps swinging (" .. swings .. " swings in 1.33 s)")
ctx.state.input.fire, ctx.state.input.fire_auto = false, false
for i = 1, 12 do frame(ctx) end

-- aiming while swinging does not switch to the aim pose
ctx.state.input.aim = { 1, 0, 0 }
ctx.state.input.fire = true
local aim_mid = false
frame(ctx)
ctx.state.input.fire = false
for i = 1, 9 do frame(ctx) if has_anim("aim") or has_anim("no_animation") then aim_mid = true end end
check(not aim_mid, "aiming mid swing: no aim/no_animation pose change")
for i = 1, 6 do frame(ctx) end
ctx.state.input.aim = { 0, 0, 0 }
for i = 1, 3 do frame(ctx) end

-- melee button with Saber still swings and is tracked
ctx.state.input.melee = true
frame(ctx)
ctx.state.input.melee = false
check(count("melee") == 1 and ctx.state.mod_cl_carry_swing ~= nil, "melee button with Saber swings and is tracked")
for i = 1, 12 do frame(ctx) end

-- drop while carrying still works
ctx.state.input.fire, ctx.state.input.interact = true, true
frame(ctx)
check(has_anim("carry_drop") and count("melee") == 0, "interact still drops the object")
ctx.state.input.fire, ctx.state.input.interact = false, false

-- exit clears tracking
ctx = new_ctx(SABER)
ctx.state.input.fire = true
frame(ctx)
CharacterStateCarry.on_exit(PLAYER, ctx, CharacterStateIdle, comp)
check(ctx.state.mod_cl_carry_swing == nil, "on_exit clears swing tracking")
for i = 1, 12 do frame(new_ctx(PISTOL)) end

-- Pistol: vanilla behaviour
ctx = new_ctx(PISTOL)
ctx.state.input.fire, ctx.state.input.fire_auto = true, true
frame(ctx)
check(count("firing_single") == 1 and count("melee") == 0 and has_anim("aim"), "pistol still shoots and aims as before")

-- Saber with session mods off: vanilla behaviour
session_on = false
ctx = new_ctx(SABER)
ctx.state.input.fire, ctx.state.input.fire_auto = true, true
frame(ctx)
check(count("melee") == 0 and count("firing_single") == 1, "session mods off: game's own carry behaviour")
session_on = true

-- patching twice does nothing
local u = CharacterStateCarry.update
hooks["lua/character_states/character_state_carry"]()
check(CharacterStateCarry.update == u, "patch applies once")

print(string.format("%d checks, %d failed", checks, fails))
if fails > 0 then os.exit(1) end
print("ALL CHECKS PASSED")
