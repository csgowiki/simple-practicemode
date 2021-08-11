#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <botmimic>
#include <csutils>

#include <practicemode>
#include <restorecvars>
#include "practicemode/util.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_CSUtilsLoaded = false;
bool g_BotMimicLoaded = false;

// These data structures maintain a list of settings for a toggle-able option:
// the name, the cvar/value for the enabled option, and the cvar/value for the disabled option.
// Note: the first set of values for these data structures is the overall-practice mode cvars,
// which aren't toggle-able or named.
ArrayList g_BinaryOptionIds;
ArrayList g_BinaryOptionNames;
ArrayList g_BinaryOptionEnabled;
ArrayList g_BinaryOptionChangeable;
ArrayList g_BinaryOptionEnabledCvars;
ArrayList g_BinaryOptionEnabledValues;
ArrayList g_BinaryOptionDisabledCvars;
ArrayList g_BinaryOptionDisabledValues;
ArrayList g_BinaryOptionCvarRestore;

ArrayList g_MapList;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

// Plugin cvars
ConVar g_BotRespawnTimeCvar;
ConVar g_DryRunFreezeTimeCvar;
ConVar g_MaxHistorySizeCvar;
ConVar g_FastfowardRequiresZeroVolumeCvar;
ConVar g_MaxPlacedBotsCvar;

// Infinite money data
ConVar g_InfiniteMoneyCvar;

// Client cvars cached
int g_ClientColors[MAXPLAYERS + 1][4];
float g_ClientVolume[MAXPLAYERS + 1];

// Grenade trajectory fix data
int g_BeamSprite = -1;
ConVar g_PatchGrenadeTrajectoryCvar;
ConVar g_GrenadeTrajectoryClientColorCvar;
ConVar g_RandomGrenadeTrajectoryCvar;

ConVar g_AllowNoclipCvar;
ConVar g_GrenadeTrajectoryCvar;
ConVar g_GrenadeThicknessCvar;
ConVar g_GrenadeTimeCvar;
ConVar g_GrenadeSpecTimeCvar;

// Other cvars.
ConVar g_FlashEffectiveThresholdCvar;
ConVar g_TestFlashTeleportDelayCvar;
ConVar g_VersionCvar;

// Saved grenade locations data
#define GRENADE_ID_LENGTH 16
#define AUTH_LENGTH 64
#define AUTH_METHOD AuthId_Steam2

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryPositions[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS + 1];

ArrayList g_ClientGrenadeThrowTimes[MAXPLAYERS + 1];  // ArrayList of <int:entity, float:throw time>
                                                      // pairs of live grenades
bool g_TestingFlash[MAXPLAYERS + 1];
float g_TestingFlashOrigins[MAXPLAYERS + 1][3];
float g_TestingFlashAngles[MAXPLAYERS + 1][3];

bool g_ClientNoFlash[MAXPLAYERS + 1];
float g_LastFlashDetonateTime[MAXPLAYERS + 1];

bool g_RunningRepeatedCommand[MAXPLAYERS + 1];
char g_RunningRepeatedCommandArg[MAXPLAYERS][256];

GrenadeType g_LastGrenadeType[MAXPLAYERS + 1];
float g_LastGrenadeOrigin[MAXPLAYERS + 1][3];
float g_LastGrenadeVelocity[MAXPLAYERS + 1][3];

// Respawn values set by clients in the current session
bool g_SavedRespawnActive[MAXPLAYERS + 1];
float g_SavedRespawnOrigin[MAXPLAYERS + 1][3];
float g_SavedRespawnAngles[MAXPLAYERS + 1][3];

ArrayList g_ClientBots[MAXPLAYERS + 1];  // Bots owned by each client.
bool g_IsPMBot[MAXPLAYERS + 1];
float g_BotSpawnOrigin[MAXPLAYERS + 1][3];
float g_BotSpawnAngles[MAXPLAYERS + 1][3];
char g_BotSpawnWeapon[MAXPLAYERS + 1][64];
bool g_BotCrouching[MAXPLAYERS + 1];
int g_BotNameNumber[MAXPLAYERS + 1];
float g_BotDeathTime[MAXPLAYERS + 1];

bool g_InDryRun = false;

#define PLAYER_HEIGHT 72.0
#define CROUCH_PLAYER_HEIGHT (PLAYER_HEIGHT - 18.0)
#define CLASS_LENGTH 64

const int kMaxBackupsPerMap = 50;

// These must match the values used by cl_color.
enum ClientColor {
  ClientColor_Yellow = 0,
  ClientColor_Purple = 1,
  ClientColor_Green = 2,
  ClientColor_Blue = 3,
  ClientColor_Orange = 4,
};

int g_LastNoclipCommand[MAXPLAYERS + 1];

// Timer data. Supports 3 modes:
enum TimerType {
  TimerType_Increasing_Movement = 0,  // Increasing timer, begins when client moves.
  TimerType_Increasing_Manual = 1,    // Increasing timer, begins as soon as command is run.
  TimerType_Countdown_Movement = 2,   // Countdown, begins when client moves.
};

bool g_RunningTimeCommand[MAXPLAYERS + 1];
bool g_RunningLiveTimeCommand[MAXPLAYERS + 1];  // Used by .timer2 & .countdown, gets set to true
                                                // when the client begins moving.
float g_TimerDuration[MAXPLAYERS + 1];  // Used by .countdown, set to the length of the countdown.
TimerType g_TimerType[MAXPLAYERS + 1];
float g_LastTimeCommand[MAXPLAYERS + 1];
bool g_OnCountDownRec[MAXPLAYERS + 1];

MoveType g_PreFastForwardMoveTypes[MAXPLAYERS + 1];

enum GrenadeMenuType {
  GrenadeMenuType_Invalid = -1,
  GrenadeMenuType_PlayersAndCategories = 0,
  GrenadeMenuType_Categories = 1,
  GrenadeMenuType_OnePlayer = 2,
  GrenadeMenuType_OneCategory = 3,  // Note: empty category "" = all nades.
  GrenadeMenuType_MatchingName = 4,
  GrenadeMenuType_MatchingId = 5,
  GrenadeMenuType_MultiCategory = 6,
};

// Data storing spawn priorities.
ArrayList g_CTSpawns = null;
ArrayList g_TSpawns = null;
KeyValues g_NamedSpawnsKv = null;

enum UserSetting {
  UserSetting_ShowAirtime = 1,
  UserSetting_NoGrenadeTrajectory = 0
};

#define USERSETTING_NUMSETTINGS 2
#define USERSETTING_DISPLAY_LENGTH 128
Handle g_UserSettingCookies[USERSETTING_NUMSETTINGS];
bool g_UserSettingDefaults[USERSETTING_NUMSETTINGS];
char g_UserSettingDisplayName[USERSETTING_NUMSETTINGS][USERSETTING_DISPLAY_LENGTH];

// Forwards
Handle g_OnPracticeModeSettingChanged = INVALID_HANDLE;
Handle g_OnPracticeModeSettingsRead = INVALID_HANDLE;

#define CHICKEN_MODEL "models/chicken/chicken.mdl"

#include "practicemode/botreplay_new.sp"

#include "practicemode/backups.sp"
#include "practicemode/bots.sp"
#include "practicemode/bots_menu.sp"
#include "practicemode/natives.sp"
#include "practicemode/commands.sp"
#include "practicemode/timers_menu.sp"
#include "practicemode/debug.sp"
#include "practicemode/grenade_commands.sp"
#include "practicemode/grenade_utils.sp"
#include "practicemode/settings_menu.sp"
#include "practicemode/spawns.sp"

// clang-format off
public Plugin myinfo = {
  name = "Simple Practicemode",
  author = "CarOL(based on splewis)",
  description = "A light-weight practicemode",
  version = PLUGIN_VERSION,
  url = "https://github.com/hx-w/simple-practicemode"
};
// clang-format on

public void OnPluginStart() {
  AddCommandListener(Command_TeamJoin, "jointeam");
  // Forwards
  g_OnPracticeModeSettingChanged = CreateGlobalForward(
      "PM_OnPracticeModeEnabled", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
  g_OnPracticeModeSettingsRead = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);

  // Init data structures to be read from the config file
  g_BinaryOptionIds = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionEnabled = new ArrayList();
  g_BinaryOptionChangeable = new ArrayList();
  g_BinaryOptionEnabledCvars = new ArrayList();
  g_BinaryOptionEnabledValues = new ArrayList();
  g_BinaryOptionDisabledCvars = new ArrayList();
  g_BinaryOptionDisabledValues = new ArrayList();
  g_BinaryOptionCvarRestore = new ArrayList();
  g_MapList = new ArrayList(PLATFORM_MAX_PATH + 1);
  ReadPracticeSettings();

  // Setup stuff for grenade history
  HookEvent("flashbang_detonate", Event_FlashDetonate);
  HookEvent("smokegrenade_detonate", Event_SmokeDetonate);
  HookEvent("player_blind", Event_PlayerBlind);

  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_GrenadeHistoryPositions[i] = new ArrayList(3);
    g_GrenadeHistoryAngles[i] = new ArrayList(3);
    g_ClientGrenadeThrowTimes[i] = new ArrayList(2);
    g_ClientBots[i] = new ArrayList();
    g_OnCountDownRec[i] = false;
  }

  // for test
  {
    RegAdminCmd("sm_botreplaytest", Command_BotReplayTest, ADMFLAG_CHANGEMAP);
    PM_AddChatAlias(".test-replay", "sm_botreplaytest");
    RegAdminCmd("sm_startrecord", Command_StartRecord, ADMFLAG_CHANGEMAP);
    PM_AddChatAlias(".test-rec", "sm_startrecord");
    RegAdminCmd("sm_stoprecord", Command_StopRecord, ADMFLAG_CHANGEMAP);
    PM_AddChatAlias(".test-stoprec", "sm_stoprecord");
  }

  {
    RegAdminCmd("sm_practicemap", Command_Map, ADMFLAG_CHANGEMAP);
    PM_AddChatAlias(".map", "sm_practicemap");

    RegAdminCmd(
        "practicemode_debuginfo", Command_DebugInfo, ADMFLAG_CHANGEMAP,
        "Dumps debug info to a file (addons/sourcemod/logs/practicemode_debuginfo.txt by default)");
  }

  // Grenade history commands
  {
    RegConsoleCmd("sm_grenadeback", Command_GrenadeBack);
    PM_AddChatAlias(".back", "sm_grenadeback");

    RegConsoleCmd("sm_grenadeforward", Command_GrenadeForward);
    PM_AddChatAlias(".forward", "sm_grenadeforward");

    RegConsoleCmd("sm_lastgrenade", Command_LastGrenade);
    PM_AddChatAlias(".last", "sm_lastgrenade");

    RegConsoleCmd("sm_clearnades", Command_ClearNades);
    PM_AddChatAlias(".clearnades", "sm_clearnades");
  }

  // Spawn commands
  {
    RegConsoleCmd("sm_gotospawn", Command_GotoSpawn);
    PM_AddChatAlias(".spawn", "sm_gotospawn");
    PM_AddChatAlias(".bestspawn", "sm_gotospawn");

    RegConsoleCmd("sm_gotospawnct", Command_GotoSpawnCT);
    PM_AddChatAlias(".ctspawn", "sm_gotospawnct");

    RegConsoleCmd("sm_gotospawnt", Command_GotoSpawnT);
    PM_AddChatAlias(".tspawn", "sm_gotospawnt");

    RegConsoleCmd("sm_worstspawn", Command_GotoWorstSpawn);
    PM_AddChatAlias(".worstspawn", "sm_worstspawn");

    RegConsoleCmd("sm_namespawn", Command_SaveSpawn);
    PM_AddChatAlias(".namespawn", "sm_namespawn");
  }

  // csutils powered nade stuff.
  {
    RegConsoleCmd("sm_throw", Command_Throw);
    PM_AddChatAlias(".throw", "sm_throw");
    PM_AddChatAlias(".rethrow", "sm_throw");
  }

  // Bot commands
  {
    RegConsoleCmd("sm_bot", Command_Bot);
    PM_AddChatAlias(".bot", "sm_bot");

    RegConsoleCmd("sm_tbot", Command_TBot);
    PM_AddChatAlias(".tbot", "sm_tbot");
    RegConsoleCmd("sm_ctbot", Command_CTBot);
    PM_AddChatAlias(".ctbot", "sm_ctbot");

    RegConsoleCmd("sm_movebot", Command_MoveBot);
    PM_AddChatAlias(".movebot", "sm_movebot");

    RegConsoleCmd("sm_crouchbot", Command_CrouchBot);
    PM_AddChatAlias(".crouchbot", "sm_crouchbot");
    PM_AddChatAlias(".cbot", "sm_crouchbot");

    RegConsoleCmd("sm_botplace", Command_BotPlace);
    PM_AddChatAlias(".botplace", "sm_botplace");
    PM_AddChatAlias(".bot2", "sm_botplace");

    RegConsoleCmd("sm_swapbot", Command_SwapBot);
    PM_AddChatAlias(".swapbot", "sm_swapbot");
    PM_AddChatAlias(".botswap", "sm_swapbot");

    RegConsoleCmd("sm_boost", Command_Boost);
    PM_AddChatAlias(".boost", "sm_boost");

    RegConsoleCmd("sm_crouchboost", Command_CrouchBoost);
    PM_AddChatAlias(".crouchboost", "sm_crouchboost");
    PM_AddChatAlias(".cboost", "sm_crouchboost");

    RegConsoleCmd("sm_removebot", Command_RemoveBot);
    PM_AddChatAlias(".removebot", "sm_removebot");
    PM_AddChatAlias(".kickbot", "sm_removebot");
    PM_AddChatAlias(".clearbot", "sm_removebot");
    PM_AddChatAlias(".nobot", "sm_removebot");
    PM_AddChatAlias(".deletebot", "sm_removebot");

    RegConsoleCmd("sm_removebots", Command_RemoveBots);
    PM_AddChatAlias(".kickbots", "sm_removebots");
    PM_AddChatAlias(".clearbots", "sm_removebots");
    PM_AddChatAlias(".nobots", "sm_removebots");

    RegConsoleCmd("sm_savebots", Command_SaveBots);
    PM_AddChatAlias(".savebots", "sm_savebots");

    RegConsoleCmd("sm_loadbots", Command_LoadBots);
    PM_AddChatAlias(".loadbots", "sm_loadbots");

    RegConsoleCmd("sm_botsmenu", Command_BotsMenu);
    PM_AddChatAlias(".bots", "sm_botsmenu");
  }

  // Saved grenade location commands
  {
    RegConsoleCmd("sm_respawn", Command_Respawn);
    PM_AddChatAlias(".respawn", "sm_respawn");

    RegConsoleCmd("sm_stoprespawn", Command_StopRespawn);
    PM_AddChatAlias(".stoprespawn", "sm_stoprespawn");

    RegConsoleCmd("sm_spec", Command_Spec);
    PM_AddChatAlias(".spec", "sm_spec");

    RegConsoleCmd("sm_joint", Command_JoinT);
    PM_AddChatAlias(".t", "sm_joint");

    RegConsoleCmd("sm_joinct", Command_JoinCT);
    PM_AddChatAlias(".ct", "sm_joinct");
  }

  // Other commands
  {
    RegConsoleCmd("sm_testflash", Command_TestFlash);

    PM_AddChatAlias(".flash", "sm_testflash");
    PM_AddChatAlias(".testflash", "sm_testflash");
    PM_AddChatAlias(".startflash", "sm_testflash");

    RegConsoleCmd("sm_stopflash", Command_StopFlash);
    PM_AddChatAlias(".endflash", "sm_stopflash");
    PM_AddChatAlias(".stopflash", "sm_stopflash");

    RegConsoleCmd("sm_noflash", Command_NoFlash);
    PM_AddChatAlias(".noflash", "sm_noflash");

    // TODO: A timer menu may be more accesible to users, as the number of timer types continues to
    // increase...
    RegConsoleCmd("sm_timers", Command_TimersMenu);
    PM_AddChatAlias(".timers", "sm_timers");
    PM_AddChatAlias(".times", "sm_timers");

    RegConsoleCmd("sm_time", Command_Time);
    PM_AddChatAlias(".timer", "sm_time");
    PM_AddChatAlias(".time", "sm_time");

    RegConsoleCmd("sm_time2", Command_Time2);
    PM_AddChatAlias(".timer2", "sm_time2");

    RegConsoleCmd("sm_countdown", Command_CountDown);
    PM_AddChatAlias(".countdown", "sm_countdown");

    RegConsoleCmd("sm_fastforward", Command_FastForward);
    PM_AddChatAlias(".fastforward", "sm_fastforward");
    PM_AddChatAlias(".fast", "sm_fastforward");
    PM_AddChatAlias(".ff", "sm_fastforward");

    RegConsoleCmd("sm_pmsettings", Command_Settings);
    PM_AddChatAlias(".settings", "sm_pmsettings");

    RegConsoleCmd("sm_repeat", Command_Repeat);
    PM_AddChatAlias(".repeat", "sm_repeat");

    RegConsoleCmd("sm_stoprepeat", Command_StopRepeat);
    PM_AddChatAlias(".stoprepeat", "sm_stoprepeat");

    RegConsoleCmd("sm_delay", Command_Delay);
    PM_AddChatAlias(".delay", "sm_delay");

    RegConsoleCmd("sm_stopall", Command_StopAll);
    PM_AddChatAlias(".stop", "sm_stopall");

    RegConsoleCmd("sm_dryrun", Command_DryRun);
    PM_AddChatAlias(".dry", "sm_dryrun");
    PM_AddChatAlias(".dryrun", "sm_dryrun");

    RegConsoleCmd("sm_enablesetting", Command_Enable);
    PM_AddChatAlias(".enable", "sm_enablesetting");

    RegConsoleCmd("sm_disablesetting", Command_Disable);
    PM_AddChatAlias(".disable", "sm_disablesetting");

    RegConsoleCmd("sm_god", Command_God);
    PM_AddChatAlias(".god", "sm_god");

    RegConsoleCmd("sm_endround", Command_EndRound);
    PM_AddChatAlias(".endround", "sm_endround");

    RegConsoleCmd("sm_break", Command_Break);
    PM_AddChatAlias(".break", "sm_break");
  }

  // New Plugin cvars
  g_BotRespawnTimeCvar = CreateConVar("sm_practicemode_bot_respawn_time", "3.0",
                                      "How long it should take bots placed with .bot to respawn");
  g_DryRunFreezeTimeCvar = CreateConVar("sm_practicemode_dry_run_freeze_time", "6",
                                        "Freezetime after running the .dryrun command.");
  g_MaxHistorySizeCvar = CreateConVar(
      "sm_practicemode_max_grenade_history_size", "5",
      "Maximum number of previous grenade throws saved in temporary history per-client. The temporary history is reset every map change. Set to 0 to disable.");
  g_MaxPlacedBotsCvar =
      CreateConVar("sm_practicemode_max_placed_bots", "10",
                   "Maximum number of static bots a single client may have placed at once.");

  g_FlashEffectiveThresholdCvar =
      CreateConVar("sm_practicemode_flash_effective_threshold", "2.0",
                   "How many seconds a flash must last to be considered effective");
  g_TestFlashTeleportDelayCvar =
      CreateConVar("sm_practicemode_test_flash_delay", "0.3",
                   "Seconds to wait before teleporting a player using .flash");

  g_FastfowardRequiresZeroVolumeCvar = CreateConVar(
      "sm_practicemode_fastforward_requires_zero_volume", "1",
      "Whether all players must have a very low volume to allow the .ff command to be used.");

  g_VersionCvar = CreateConVar("sm_practicemode_version", PLUGIN_VERSION,
                               "Current practicemode version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  AutoExecConfig(true, "practicemode");

  // New cvars we don't want saved in the autoexec'd file
  g_AllowNoclipCvar = 
      CreateConVar("sm_allow_noclip", "0",
                  "Whether players may use .noclip in chat to toggle noclip", FCVAR_DONTRECORD);
  g_InfiniteMoneyCvar = 
      CreateConVar("sm_infinite_money", "0",
                  "Whether clients recieve infinite money", FCVAR_DONTRECORD);
  g_PatchGrenadeTrajectoryCvar =
      CreateConVar("sm_patch_grenade_trajectory_cvar", "1",
                   "Whether the plugin patches sv_grenade_trajectory with its own grenade trails");
  g_GrenadeTrajectoryClientColorCvar =
      CreateConVar("sm_grenade_trajectory_use_player_color", "0",
                   "Whether to use client colors when drawing grenade trajectories");
  g_RandomGrenadeTrajectoryCvar =
      CreateConVar("sm_grenade_trajectory_random_color", "0",
                   "Whether to randomize all grenade trajectory colors");

  // Patched builtin cvars
  g_GrenadeTrajectoryCvar = GetCvar("sv_grenade_trajectory");
  g_GrenadeThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
  g_GrenadeTimeCvar = GetCvar("sv_grenade_trajectory_time");
  g_GrenadeSpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");

  // Set default client cvars
  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_ClientColors[i][0] = 0;
    g_ClientColors[i][1] = 255;
    g_ClientColors[i][2] = 0;
    g_ClientColors[i][3] = 255;
    g_ClientVolume[i] = 1.0;
  }

  g_CTSpawns = new ArrayList();
  g_TSpawns = new ArrayList();

  // Create client cookies.
  RegisterUserSetting(UserSetting_ShowAirtime, "practicemode_grenade_airtime", true,
                      "显示烟雾弹飞行时间");
  RegisterUserSetting(UserSetting_NoGrenadeTrajectory, "practicemode_no_traject", false,
                      "隐藏投掷物轨迹");

  // Remove cheats so sv_cheats isn't required for this:
  RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_BotDamageDealtEvent, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_freeze_end", Event_FreezeEnd);

  g_CSUtilsLoaded = LibraryExists("csutils");

  CreateTimer(1.0, Timer_GivePlayersMoney, _, TIMER_REPEAT);
  CreateTimer(0.1, Timer_RespawnBots, _, TIMER_REPEAT);
  CreateTimer(1.0, Timer_UpdateClientCvars, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
  OnMapEnd();
}

public void OnLibraryAdded(const char[] name) {
  g_CSUtilsLoaded = LibraryExists("csutils");
  g_BotMimicLoaded = LibraryExists("botmimic");
}

public void OnLibraryRemoved(const char[] name) {
  g_CSUtilsLoaded = LibraryExists("csutils");
  g_BotMimicLoaded = LibraryExists("botmimic");
}

/**
 * Silences all cvar changes in practice mode.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  event.BroadcastDisabled = true;
  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client) && g_SavedRespawnActive[client]) {
    TeleportEntity(client, g_SavedRespawnOrigin[client], g_SavedRespawnAngles[client], NULL_VECTOR);
  }
  if (IsPMBot(client)) {
    GiveBotParams(client);
  }

  return Plugin_Continue;
}

public void OnClientConnected(int client) {
  g_GrenadeHistoryIndex[client] = -1;
  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  ClearArray(g_ClientGrenadeThrowTimes[client]);
  g_TestingFlash[client] = false;
  g_ClientNoFlash[client] = false;
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;
  g_SavedRespawnActive[client] = false;
  g_LastGrenadeType[client] = GrenadeType_None;
  g_RunningRepeatedCommand[client] = false;
  g_OnCountDownRec[client] = false;
}

public void OnMapStart() {
  ReadPracticeSettings();
  g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");

  EnforceDirectoryExists("data/practicemode");
  EnforceDirectoryExists("data/practicemode/bots");
  EnforceDirectoryExists("data/practicemode/bots/backups");
  EnforceDirectoryExists("data/practicemode/grenades");
  EnforceDirectoryExists("data/practicemode/grenades/backups");
  EnforceDirectoryExists("data/practicemode/spawns");
  EnforceDirectoryExists("data/practicemode/spawns/backups");
  EnforceDirectoryExists("data/practicemode/replays");
  EnforceDirectoryExists("data/practicemode/replays/backups");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  Spawns_MapStart();
}

public void OnConfigsExecuted() {
  LaunchPracticeMode();
}

public void OnClientDisconnect(int client) {
  KickAllClientBots(client);

  g_IsPMBot[client] = false;

  int playerCount = 0;
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      playerCount++;
    }
  }
  if (playerCount == 0) {
    ClearBots();
  }
}

public void OnMapEnd() {
  ClearBots();
  Spawns_MapEnd();
}

public void ClearBots() {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsFakeClient(i) && g_IsPMBot[i]) {
      KickClient(i);
      g_IsPMBot[i] = false;
    }
  }
  PM_MessageToAll("服务器空闲，Bot已清空");
}

public void OnClientSettingsChanged(int client) {
  UpdateClientCvars(client);
}

public void OnClientPutInServer(int client) {
  UpdateClientCvars(client);
}

static void UpdateClientCvars(int client) {
  QueryClientConVar(client, "cl_color", QueryClientColor, client);
  QueryClientConVar(client, "volume", QueryClientVolume, client);
}

public void QueryClientColor(QueryCookie cookie, int client, ConVarQueryResult result,
                      const char[] cvarName, const char[] cvarValue) {
  int color = StringToInt(cvarValue);
  GetColor(view_as<ClientColor>(color), g_ClientColors[client]);
}

public void QueryClientVolume(QueryCookie cookie, int client, ConVarQueryResult result,
                       const char[] cvarName, const char[] cvarValue) {
  g_ClientVolume[client] = StringToFloat(cvarValue);
}

public void GetColor(ClientColor c, int array[4]) {
  int r, g, b;
  switch (c) {
    case ClientColor_Yellow: {
      r = 229;
      g = 224;
      b = 44;
    }
    case ClientColor_Purple: {
      r = 150;
      g = 45;
      b = 225;
    }
    case ClientColor_Green: {
      r = 23;
      g = 255;
      b = 102;
    }
    case ClientColor_Blue: {
      r = 112;
      g = 191;
      b = 255;
    }
    case ClientColor_Orange: {
      r = 227;
      g = 152;
      b = 33;
    }
    default: {
      r = 23;
      g = 255;
      b = 102;
    }
  }
  array[0] = r;
  array[1] = g;
  array[2] = b;
  array[3] = 255;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
                      int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed,
                      int mouse[2]) {
  if (IsPMBot(client)) {
    if (g_BotCrouching[client]) {
      buttons |= IN_DUCK;
    } else {
      buttons &= ~IN_DUCK;
    }
    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    return Plugin_Continue;
  }

  bool moving = MovingButtons(buttons);
  TimerType timer_type = g_TimerType[client];
  bool is_movement_timer =
      (timer_type == TimerType_Increasing_Movement || timer_type == TimerType_Countdown_Movement);
  bool is_movement_end_timer = timer_type == TimerType_Increasing_Movement;

  if (g_RunningTimeCommand[client] && is_movement_timer) {
    if (g_RunningLiveTimeCommand[client]) {
      // The movement timer is already running; stop it.
      if (is_movement_end_timer && !moving && GetEntityFlags(client) & FL_ONGROUND) {
        g_RunningTimeCommand[client] = false;
        g_RunningLiveTimeCommand[client] = false;
        StopClientTimer(client);
      }
    } else {
      //  We're pending a movement timer start.
      if (moving) {
        g_RunningLiveTimeCommand[client] = true;
        StartClientTimer(client);
      }
    }
  }

  return Plugin_Continue;
}

static bool MovingButtons(int buttons) {
  return buttons & IN_FORWARD != 0 || buttons & IN_MOVELEFT != 0 || buttons & IN_MOVERIGHT != 0 ||
         buttons & IN_BACK != 0;
}

public Action Command_TeamJoin(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || argc < 1)
    return Plugin_Handled;

  char arg[4];
  GetCmdArg(1, arg, sizeof(arg));
  int team = StringToInt(arg);
  SwitchPlayerTeam(client, team);

  // Since we force respawns off during bot replay, make teamswitches respawn players.
  if (team != CS_TEAM_SPECTATOR && team != CS_TEAM_NONE) {
    CS_RespawnPlayer(client);
  }

  return Plugin_Handled;

}

public Action OnClientSayCommand(int client, const char[] command, const char[] text) {
  if (IsPlayer(client) && g_OnCountDownRec[client] && StrEqual(command, "say")) {
    ClientCommand(client, "sm_countdown %s", text);
    g_OnCountDownRec[client] = false;
  }
  if (g_AllowNoclipCvar.IntValue != 0 && StrEqual(text, ".noclip") && IsPlayer(client)) {
    PerformNoclipAction(client);
  }
}

public void PerformNoclipAction(int client) {
  // The move type is also set on the next frame. This is a dirty trick to deal
  // with clients that have a double-bind of "noclip; say .noclip" to work on both
  // ESEA-practice and local sv_cheats servers. Since this plugin can have both enabled
  // (sv_cheats and allow noclip), this double bind would cause the noclip type to be toggled twice.
  // Therefore the fix is to only perform 1 noclip action per-frame per-client at most, implemented
  // by saving the frame count of each use in g_LastNoclipCommand.
  if (g_LastNoclipCommand[client] == GetGameTickCount() ||
      (g_AllowNoclipCvar.IntValue == 0 && GetCvarIntSafe("sv_cheats") == 0)) {
    return;
  }

  g_LastNoclipCommand[client] = GetGameTickCount();
  MoveType t = GetEntityMoveType(client);
  MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
  SetEntityMoveType(client, next);

  if (next == MOVETYPE_WALK) {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
  } else {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 0);
  }
}

public void ReadPracticeSettings() {
  ClearArray(g_BinaryOptionIds);
  ClearArray(g_BinaryOptionNames);
  ClearArray(g_BinaryOptionEnabled);
  ClearArray(g_BinaryOptionChangeable);
  ClearNestedArray(g_BinaryOptionEnabledCvars);
  ClearNestedArray(g_BinaryOptionEnabledValues);
  ClearNestedArray(g_BinaryOptionDisabledCvars);
  ClearNestedArray(g_BinaryOptionDisabledValues);
  ClearArray(g_BinaryOptionCvarRestore);
  ClearArray(g_MapList);

  char filePath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, filePath, sizeof(filePath), "configs/practicemode.cfg");

  KeyValues kv = new KeyValues("practice_settings");
  if (!kv.ImportFromFile(filePath)) {
    LogError("Failed to import keyvalue from practice config file \"%s\"", filePath);
    delete kv;
    return;
  }

  // Read in the binary options
  if (kv.JumpToKey("binary_options")) {
    if (kv.GotoFirstSubKey()) {
      // read each option
      do {
        char id[128];
        kv.GetSectionName(id, sizeof(id));

        char name[OPTION_NAME_LENGTH];
        kv.GetString("name", name, sizeof(name));

        char enabledString[64];
        kv.GetString("default", enabledString, sizeof(enabledString), "enabled");
        bool enabled =
            StrEqual(enabledString, "enabled", false) || StrEqual(enabledString, "enable", false);

        bool changeable = (kv.GetNum("changeable", 1) != 0);

        // read the enabled cvar list
        ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList enabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("enabled")) {
          ReadCvarKv(kv, enabledCvars, enabledValues);
          kv.GoBack();
        }

        ArrayList disabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList disabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("disabled")) {
          ReadCvarKv(kv, disabledCvars, disabledValues);
          kv.GoBack();
        }

        PM_AddSetting(id, name, enabledCvars, enabledValues, enabled, changeable, disabledCvars,
                      disabledValues);

      } while (kv.GotoNextKey());
    }
  }
  kv.Rewind();

  char map[PLATFORM_MAX_PATH + 1];
  if (kv.JumpToKey("maps")) {
    if (kv.GotoFirstSubKey(false)) {
      do {
        kv.GetSectionName(map, sizeof(map));
        g_MapList.PushString(map);
      } while (kv.GotoNextKey(false));
    }
    kv.GoBack();
  }
  if (g_MapList.Length == 0) {
    g_MapList.PushString("de_cache");
    g_MapList.PushString("de_ancient");
    g_MapList.PushString("de_dust2");
    g_MapList.PushString("de_inferno");
    g_MapList.PushString("de_mirage");
    g_MapList.PushString("de_nuke");
    g_MapList.PushString("de_overpass");
    g_MapList.PushString("de_train");
    g_MapList.PushString("de_vertigo");
  }

  Call_StartForward(g_OnPracticeModeSettingsRead);
  Call_Finish();

  delete kv;
}

public void LaunchPracticeMode() {
  ServerCommand("exec sourcemod/practicemode_start.cfg");

  ReadPracticeSettings();
  for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
    ChangeSetting(i, PM_IsSettingEnabled(i), false, true);
  }
  g_InDryRun = false;
  strcopy(MESSAGE_PREFIX, sizeof(MESSAGE_PREFIX), "[{LIGHT_GREEN}练习模式{NORMAL}]");
  PM_MessageToAll("练习模式初始化完成~");
}

stock bool ChangeSetting(int index, bool enabled, bool print = true, bool force_setting = false) {
  bool previousSetting = g_BinaryOptionEnabled.Get(index);
  if (enabled == previousSetting && !force_setting) {
    return false;
  }

  g_BinaryOptionEnabled.Set(index, enabled);

  if (enabled) {
    ArrayList cvars = g_BinaryOptionEnabledCvars.Get(index);
    ArrayList values = g_BinaryOptionEnabledValues.Get(index);
    g_BinaryOptionCvarRestore.Set(index, SaveCvars(cvars));
    ExecuteCvarLists(cvars, values);
  } else {
    ArrayList cvars = g_BinaryOptionDisabledCvars.Get(index);
    ArrayList values = g_BinaryOptionDisabledValues.Get(index);

    if (cvars != null && cvars.Length > 0 && values != null && values.Length == cvars.Length) {
      // If there are are disabled cvars explicity set.
      ExecuteCvarLists(cvars, values);
    } else {
      // If there are no "disabled" cvars explicity set, we'll just restore to the cvar
      // values before the option was enabled.
      Handle cvarRestore = g_BinaryOptionCvarRestore.Get(index);
      if (cvarRestore != INVALID_HANDLE) {
        RestoreCvars(cvarRestore, true);
        g_BinaryOptionCvarRestore.Set(index, INVALID_HANDLE);
      }
    }
  }

  char id[OPTION_NAME_LENGTH];
  char name[OPTION_NAME_LENGTH];
  g_BinaryOptionIds.GetString(index, id, sizeof(id));
  g_BinaryOptionNames.GetString(index, name, sizeof(name));

  if (print) {
    char enabledString[32];
    GetEnabledString(enabledString, sizeof(enabledString), enabled);
    if (!StrEqual(name, "")) {
      PM_MessageToAll("设置 [{GRAY}%s{NORMAL}] %s.", name, enabledString);
    }
  }

  Call_StartForward(g_OnPracticeModeSettingChanged);
  Call_PushCell(index);
  Call_PushString(id);
  Call_PushString(name);
  Call_PushCell(enabled);
  Call_Finish();

  return true;
}

public Action Timer_GivePlayersMoney(Handle timer) {
  int maxMoney = GetCvarIntSafe("mp_maxmoney", 16000);
  if (g_InfiniteMoneyCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        SetEntProp(i, Prop_Send, "m_iAccount", maxMoney);
      }
    }
  }

  return Plugin_Continue;
}

public Action Timer_UpdateClientCvars(Handle timer) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClientCvars(i);
    }
  }
  return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] className) {
  if (!IsValidEntity(entity)) {
    return;
  }

  SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

// We artifically delay the work here in OnEntitySpawned because the csutils
// plugin will spawn grenades and set the owner on spawn, and we want to be sure
// the owner is set by the time practicemode gets to the grenade.
public int OnEntitySpawned(int entity) {
  RequestFrame(DelayedOnEntitySpawned, entity);
}

public int DelayedOnEntitySpawned(int entity) {
  if (!IsValidEdict(entity)) {
    return;
  }

  char className[CLASS_LENGTH];
  GetEdictClassname(entity, className, sizeof(className));

  if (IsGrenadeProjectile(className)) {
    // Get the cl_color value for the client that threw this grenade.
    int client = Entity_GetOwner(entity);
    if (IsPlayer(client) &&
        GrenadeFromProjectileName(className) == GrenadeType_Smoke) {
      int index = g_ClientGrenadeThrowTimes[client].Push(EntIndexToEntRef(entity));
      g_ClientGrenadeThrowTimes[client].Set(index, view_as<int>(GetEngineTime()), 1);
    }

    if (IsValidEntity(entity)) {
      if (g_GrenadeTrajectoryCvar.IntValue != 0 && g_PatchGrenadeTrajectoryCvar.IntValue != 0) {
        // Send a temp ent beam that follows the grenade entity to all other clients.
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
          }
          if (GetSetting(client, UserSetting_NoGrenadeTrajectory)) {
            continue;
          }
          // Note: the technique using temporary entities is taken from InternetBully's NadeTails
          // plugin which you can find at https://forums.alliedmods.net/showthread.php?t=240668
          float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTimeCvar.FloatValue
                                                               : g_GrenadeTimeCvar.FloatValue;

          int colors[4];
          if (g_RandomGrenadeTrajectoryCvar.IntValue > 0) {
            colors[0] = GetRandomInt(0, 255);
            colors[1] = GetRandomInt(0, 255);
            colors[2] = GetRandomInt(0, 255);
            colors[3] = 255;
          } else if (g_GrenadeTrajectoryClientColorCvar.IntValue > 0 && IsPlayer(client)) {
            colors = g_ClientColors[client];
          } else {
            colors = g_ClientColors[0];
          }

          TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThicknessCvar.FloatValue * 5,
                             g_GrenadeThicknessCvar.FloatValue * 5, 1, colors);
          TE_SendToClient(i);
        }
      }

      // If the user recently indicated they are testing a flash (.flash),
      // teleport to that spot.
      if (GrenadeFromProjectileName(className) == GrenadeType_Flash && g_TestingFlash[client]) {
        float delay = g_TestFlashTeleportDelayCvar.FloatValue;
        if (delay <= 0.0) {
          delay = 0.1;
        }

        CreateTimer(delay, Timer_TeleportClient, GetClientSerial(client));
      }
    }
  }
}

public Action Timer_TeleportClient(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    float velocity[3];
    TeleportEntity(client, g_TestingFlashOrigins[client], g_TestingFlashAngles[client], velocity);
    SetEntityMoveType(client, MOVETYPE_NONE);
  }
}

public Action Timer_FakeGrenadeBack(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    FakeClientCommand(client, "sm_lastgrenade");
  }
}

public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast) {
  GrenadeDetonateTimerHelper(event, "烟雾弹");
}

public void GrenadeDetonateTimerHelper(Event event, const char[] grenadeName) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  int entity = event.GetInt("entityid");

  if (IsPlayer(client)) {
    for (int i = 0; i < g_ClientGrenadeThrowTimes[client].Length; i++) {
      int ref = g_ClientGrenadeThrowTimes[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        float dt = GetEngineTime() - view_as<float>(g_ClientGrenadeThrowTimes[client].Get(i, 1));
        g_ClientGrenadeThrowTimes[client].Erase(i);
        if (GetSetting(client, UserSetting_ShowAirtime)) {
          PM_Message(client, "%s飞行时间:\x05 %.1f\x01 秒", grenadeName, dt);
        }
        break;
      }
    }
  }
}

public Action Event_FlashDetonate(Event event, const char[] name, bool dontBroadcast) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    // Get the impact of the flash next frame, since doing it in
    // this frame doesn't work.
    RequestFrame(GetTestingFlashInfo, GetClientSerial(client));
  }

  g_LastFlashDetonateTime[client] = GetGameTime();
}

public void GetTestingFlashInfo(int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    float flashDuration = GetFlashDuration(client);
    PM_Message(client, "闪光持续时间: \x05%.1f \x01秒", flashDuration);

    if (flashDuration < g_FlashEffectiveThresholdCvar.FloatValue) {
      PM_Message(client, "{DARK_RED}无效的闪光{NORMAL}");
      CreateTimer(1.0, Timer_FakeGrenadeBack, GetClientSerial(client));
    } else {
      float delay = flashDuration - 1.0;
      if (delay <= 0.0)
        delay = 0.1;

      CreateTimer(delay, Timer_FakeGrenadeBack, GetClientSerial(client));
    }
  }
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsPlayer(i)) {
      continue;
    }

    if (g_ClientNoFlash[i]) {
      g_ClientNoFlash[i] = false;
      PM_Message(i, "在回合开始时禁用闪光屏蔽");
    }

    if (GetEntityMoveType(i) == MOVETYPE_NOCLIP) {
      SetEntityMoveType(i, MOVETYPE_WALK);
      PM_Message(i, "在回合开始时禁用飞行");
    }
  }

  return Plugin_Handled;
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (!IsPlayer(client))
    return;

  // splits to find the first word to do a chat alias command check
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }

  if (chatCommand[0]) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      g_ChatAliases.GetString(i, alias, sizeof(alias));
      g_ChatAliasesCommands.GetString(i, cmd, sizeof(cmd));

      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
        break;
      }
    }
  }

  if (StrEqual(chatCommand, ".help")) {
  // TODO 
  }
}

public void CSU_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3],
                        const float velocity[3]) {
  if (IsPlayer(client)) {
    AddGrenadeToHistory(client);
    g_LastGrenadeType[client] = grenadeType;
    g_LastGrenadeOrigin[client] = origin;
    g_LastGrenadeVelocity[client] = velocity;
  }
}
