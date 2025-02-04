
CONVARS = {
	maxdeaths = CreateConVar("game_maxdeaths", 	"3", {FCVAR_REPLICATED, FCVAR_ARCHIVE}),
	difficulty = CreateConVar("hl2c_difficulty", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE}),
	physgun = CreateConVar("hl2c_admin_physgun", "0", {FCVAR_REPLICATED, FCVAR_ARCHIVE}),
	noclip = CreateConVar("hl2c_admin_noclip", "0", {FCVAR_REPLICATED, FCVAR_ARCHIVE}),
}

concommand.Add("hl2c_next_map", function(pl) if SERVER and pl and pl:IsAdmin() then GAMEMODE:NextMap() end end)
concommand.Add("hl2c_restart_map", function(pl, command, arguments) if SERVER and pl and pl:IsAdmin() then GAMEMODE:RestartMap() end end)
concommand.Add("hl2c_start_hl2", function(pl, command, arguments) if SERVER and pl and pl:IsAdmin() then GAMEMODE:FirstMap() end end)

PLAYER_SPEED = {160, 250}

FAILURE_SOUNDS = {
	"sound/You Failed.wav"
}

NEXT_MAP_PERCENT = 60

NEXT_MAP_TIME = 5


// Points to give a player for killing an NPC (if non-one)
NPC_POINT_VALUES = {
	["npc_antlionguard"] = 2,
	["npc_citizen"] = 0,
	["npc_combinedropship"] = 3,
	["npc_combinegunship"] = 2,
	["npc_crow"] = 0,
	["npc_helicopter"] = 3,
	["npc_ministrider"] = 2,
	["npc_pigeon"] = 0,
	["npc_strider"] = 3
}


// Play Episode 1 after HL2 [0 = No, 1 = Yes] (Default: 0)
PLAY_EPISODE_1 = 0


// Play Episode 2 after Episode 1 [0 = No, 1 = Yes] (Default: 0)
PLAY_EPISODE_2 = 0


// Seconds before the map is restarted (Default: 10)
RESTART_MAP_TIME = 2


// Models the player can be
PLAYER_MODELS = {
	"models/player/group01/female_01.mdl",
	"models/player/group01/female_02.mdl",
	"models/player/group01/female_03.mdl",
	"models/player/group01/female_04.mdl",
	"models/player/group01/female_06.mdl",
	"models/player/group01/female_07.mdl",
	"models/player/group01/male_01.mdl",
	"models/player/group01/male_02.mdl",
	"models/player/group01/male_03.mdl",
	"models/player/group01/male_04.mdl",
	"models/player/group01/male_05.mdl",
	"models/player/group01/male_06.mdl",
	"models/player/group01/male_07.mdl",
	"models/player/group01/male_08.mdl",
	"models/player/group01/male_09.mdl",
	"models/player/group03/female_01.mdl",
	"models/player/group03/female_02.mdl",
	"models/player/group03/female_03.mdl",
	"models/player/group03/female_04.mdl",
	"models/player/group03/female_06.mdl",
	"models/player/group03/female_07.mdl",
	"models/player/group03/male_01.mdl",
	"models/player/group03/male_02.mdl",
	"models/player/group03/male_03.mdl",
	"models/player/group03/male_04.mdl",
	"models/player/group03/male_05.mdl",
	"models/player/group03/male_06.mdl",
	"models/player/group03/male_07.mdl",
	"models/player/group03/male_08.mdl",
	"models/player/group03/male_09.mdl"
}


// If everyone beats the level, one of these will be played
// Leave blank to disable
SUCCESS_SOUNDS = {
	"vo/announcer_success.wav",
	"vo/announcer_victory.wav",
	"vo/announcer_we_succeeded.wav"
}


// Number of seconds before a player is vulnerable after they spawn (Default: 10)
VULNERABLE_TIME = 10