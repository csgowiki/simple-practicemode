public Action Command_NoFlash(int client, int args) {
  g_ClientNoFlash[client] = !g_ClientNoFlash[client];
  if (g_ClientNoFlash[client]) {
    PM_Message(client, "Enabled noflash. Use .noflash again to disable.");
    RequestFrame(KillFlashEffect, GetClientSerial(client));
  } else {
    PM_Message(client, "Disabled noflash.");
  }
  return Plugin_Handled;
}

public Action Command_Time(int client, int args) {
  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "When you start moving a timer will run until you stop moving.");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Movement;
  } else {
    // Early stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_Time2(int client, int args) {
  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "Type .timer2 to stop the timer again.");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Manual;
    StartClientTimer(client);
  } else {
    // Stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_CountDown(int client, int args) {
  float timer_duration = float(GetRoundTimeSeconds());
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    timer_duration = StringToFloat(arg);
  }

  PM_Message(client, "When you start moving a countdown will begin. Use .stop to cancel it.");
  g_RunningTimeCommand[client] = true;
  g_RunningLiveTimeCommand[client] = false;
  g_TimerType[client] = TimerType_Countdown_Movement;
  g_TimerDuration[client] = timer_duration;
  StartClientTimer(client);

  return Plugin_Handled;
}

public void StartClientTimer(int client) {
  g_LastTimeCommand[client] = GetEngineTime();
  CreateTimer(0.1, Timer_DisplayClientTimer, GetClientSerial(client),
              TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void StopClientTimer(int client) {
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;

  // Only display the elapsed duration for increasing timers (not a countdown).
  TimerType timer_type = g_TimerType[client];
  if (timer_type == TimerType_Increasing_Manual || timer_type == TimerType_Increasing_Movement) {
    float dt = GetEngineTime() - g_LastTimeCommand[client];
    PM_Message(client, "Timer result: %.2f seconds", dt);
    PrintCenterText(client, "Time: %.2f seconds", dt);
  }
}

public Action Timer_DisplayClientTimer(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_RunningTimeCommand[client]) {
    TimerType timer_type = g_TimerType[client];
    if (timer_type == TimerType_Countdown_Movement) {
      float time_left = g_TimerDuration[client];
      if (g_RunningLiveTimeCommand[client]) {
        float dt = GetEngineTime() - g_LastTimeCommand[client];
        time_left -= dt;
      }
      if (time_left >= 0.0) {
        int seconds = RoundToCeil(time_left);
        PrintCenterText(client, "Time: %d:%2d", seconds / 60, seconds % 60);
      } else {
        StopClientTimer(client);
      }
      // TODO: can we clear the hint text here quicker? Perhaps an empty PrintHintText(client, "")
      // call works?
    } else {
      float dt = GetEngineTime() - g_LastTimeCommand[client];
      PrintCenterText(client, "Time: %.1f seconds", dt);
    }
    return Plugin_Continue;
  }
  return Plugin_Stop;
}

public Action Command_Respawn(int client, int args) {
  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
    return Plugin_Handled;
  }

  g_SavedRespawnActive[client] = true;
  GetClientAbsOrigin(client, g_SavedRespawnOrigin[client]);
  GetClientEyeAngles(client, g_SavedRespawnAngles[client]);
  PM_Message(
      client,
      "Saved respawn point. When you die will you respawn here, use {GREEN}.stop {NORMAL}to cancel.");
  return Plugin_Handled;
}

public Action Command_StopRespawn(int client, int args) {
  g_SavedRespawnActive[client] = false;
  PM_Message(client, "Cancelled respawning at your saved position.");
  return Plugin_Handled;
}

public Action Command_Spec(int client, int args) {
  FakeClientCommand(client, "jointeam 1");
  return Plugin_Handled;
}

public Action Command_JoinT(int client, int args) {
  FakeClientCommand(client, "jointeam 2");
  return Plugin_Handled;
}

public Action Command_JoinCT(int client, int args) {
  FakeClientCommand(client, "jointeam 3");
  return Plugin_Handled;
}

public Action Command_StopAll(int client, int args) {
  if (g_SavedRespawnActive[client]) {
    Command_StopRespawn(client, 0);
  }
  if (g_TestingFlash[client]) {
    Command_StopFlash(client, 0);
  }
  if (g_RunningTimeCommand[client]) {
    StopClientTimer(client);
  }
  if (g_RunningRepeatedCommand[client]) {
    Command_StopRepeat(client, 0);
  }
  if (g_BotMimicLoaded && IsReplayPlaying()) {
    CancelAllReplays();
  }
  if (g_BotMimicLoaded && BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  }
  return Plugin_Handled;
}

public Action Command_FastForward(int client, int args) {
  if (g_FastfowardRequiresZeroVolumeCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && g_ClientVolume[i] > 0.01) {
        PM_Message(client, "所有玩家的音量必须调整至\x020.01\x01以下才可以使用.ff指令快进时间");
        return Plugin_Handled;
      }
    }
  }

  // Freeze clients so it's not really confusing.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      g_PreFastForwardMoveTypes[i] = GetEntityMoveType(i);
      SetEntityMoveType(i, MOVETYPE_NONE);
    }
  }

  // Smokes last around 18 seconds.
  PM_MessageToAll("\x09服务器时间快进20秒...");
  SetCvar("host_timescale", 10);
  CreateTimer(20.0, Timer_ResetTimescale);

  return Plugin_Handled;
}

public Action Timer_ResetTimescale(Handle timer) {
  SetCvar("host_timescale", 1);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      SetEntityMoveType(i, g_PreFastForwardMoveTypes[i]);
    }
  }
  return Plugin_Handled;
}

public Action Command_Repeat(int client, int args) {
  if (args < 2) {
    PM_Message(client, "用法: .repeat <间隔秒数> <任意聊天栏命令>");
    return Plugin_Handled;
  }

  char timeString[64];
  char fullString[256];
  if (GetCmdArgString(fullString, sizeof(fullString)) &&
      SplitOnSpace(fullString, timeString, sizeof(timeString), g_RunningRepeatedCommandArg[client],
                   sizeof(fullString))) {
    float time = StringToFloat(timeString);
    if (time <= 0.0) {
      PM_Message(client, "Usage: .repeat <interval in seconds> <any chat command>");
      return Plugin_Handled;
    }

    g_RunningRepeatedCommand[client] = true;
    FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
    CreateTimer(time, Timer_RepeatCommand, GetClientSerial(client),
                TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    PM_Message(client, "正在重复执行命令，间隔 {YELLOW}%.1f{NORMAL} 秒", time);
    PM_Message(client, "输入 {GREEN}.stop {NORMAL}停止");
  }

  return Plugin_Handled;
}

public Action Timer_RepeatCommand(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (!IsPlayer(client) || !g_RunningRepeatedCommand[client]) {
    return Plugin_Stop;
  }

  FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
  return Plugin_Continue;
}

public Action Command_StopRepeat(int client, int args) {
  if (g_RunningRepeatedCommand[client]) {
    g_RunningRepeatedCommand[client] = false;
    PM_Message(client, "取消重复执行命令");
  }
  return Plugin_Handled;
}

public Action Command_Delay(int client, int args) {
  if (args < 2) {
    PM_Message(client, "用法: .delay <间隔秒数> <任意聊天框命令>");
    return Plugin_Handled;
  }

  char timeString[64];
  char fullString[256];
  if (GetCmdArgString(fullString, sizeof(fullString)) &&
      SplitOnSpace(fullString, timeString, sizeof(timeString), g_RunningRepeatedCommandArg[client],
                   sizeof(fullString))) {
    float time = StringToFloat(timeString);
    if (time <= 0.0) {
      PM_Message(client, "Usage: .repeat <interval in seconds> <any chat command>");
      return Plugin_Handled;
    }

    CreateTimer(time, Timer_DelayedComand, GetClientSerial(client));
  }

  return Plugin_Handled;
}

public Action Timer_DelayedComand(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    FakeClientCommand(client, "say %s", g_RunningRepeatedCommandArg[client]);
  }
  return Plugin_Stop;
}

public Action Command_Map(int client, int args) {
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    // Before trying to change to the arg first, check to see if
    // there's a clear match in the maplist
    for (int i = 0; i < g_MapList.Length; i++) {
      char map[PLATFORM_MAX_PATH];
      g_MapList.GetString(i, map, sizeof(map));
      if (StrContains(map, arg, false) >= 0) {
        ChangeMap(map);
        return Plugin_Handled;
      }
    }
    ChangeMap(arg);

  } else {
    Menu menu = new Menu(ChangeMapHandler);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.SetTitle("Select a map:");
    for (int i = 0; i < g_MapList.Length; i++) {
      char map[PLATFORM_MAX_PATH];
      g_MapList.GetString(i, map, sizeof(map));
      char cleanedMapName[PLATFORM_MAX_PATH];
      CleanMapName(map, cleanedMapName, sizeof(cleanedMapName));
      AddMenuInt(menu, i, cleanedMapName);
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  }

  return Plugin_Handled;
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int index = GetMenuInt(menu, param2);
    char map[PLATFORM_MAX_PATH];
    g_MapList.GetString(index, map, sizeof(map));
    ChangeMap(map);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void ChangeSettingById(const char[] id, bool setting) {
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionIds.GetString(i, name, sizeof(name));
    if (StrEqual(name, id, false)) {
      ChangeSetting(i, setting, true);
    }
  }
}

public Action Command_DryRun(int client, int args) {
  if (g_InDryRun) {
    strcopy(MESSAGE_PREFIX, sizeof(MESSAGE_PREFIX), "[{LIGHT_GREEN}练习模式{NORMAL}]");
    DryRunSetting(client, true, 0);
  }
  else {
    strcopy(MESSAGE_PREFIX, sizeof(MESSAGE_PREFIX), "[{LIGHT_RED}实战模式{NORMAL}]");
    DryRunSetting(client, false, g_DryRunFreezeTimeCvar.IntValue);
  }
  g_InDryRun = !g_InDryRun;
  PM_MessageToAll("输入{DARK_RED}.dry{NORMAL}或{DARK_RED}.dryrun{NORMAL}切换[{LIGHT_GREEN}练习模式{NORMAL}]与[{LIGHT_RED}实战模式{NORMAL}]");
  return Plugin_Handled;
}

void DryRunSetting(int client, bool status, int mp_freezetime) {
  SetCvar("mp_freezetime", mp_freezetime);
  ChangeSettingById("allradar", status);
  ChangeSettingById("blockroundendings", status);
  ChangeSettingById("grenadetrajectory", status);
  ChangeSettingById("infiniteammo", status);
  ChangeSettingById("noclip", status);
  ChangeSettingById("respawning", status);
  ChangeSettingById("showimpacts", status);

  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = status;
    g_RunningRepeatedCommand[i] = status;
    g_SavedRespawnActive[i] = false;
    g_ClientNoFlash[client] = status;
    if (IsPlayer(i) && !status) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
}

static void ChangeSettingArg(int client, const char[] arg, bool enabled) {
  if (StrEqual(arg, "all", false)) {
    for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
      ChangeSetting(i, enabled, true);
    }
    return;
  }

  ArrayList indexMatches = new ArrayList();
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionNames.GetString(i, name, sizeof(name));
    if (StrContains(name, arg, false) >= 0) {
      indexMatches.Push(i);
    }
  }

  if (indexMatches.Length == 0) {
    PM_Message(client, "没有找到设置 \"%s\"", arg);
  } else if (indexMatches.Length == 1) {
    if (!ChangeSetting(indexMatches.Get(0), enabled, true)) {
      PM_Message(client, "该设置已启用");
    }
  } else {
    PM_Message(client, "匹配到多项设置 \"%s\"", arg);
  }

  delete indexMatches;
}

public Action Command_Enable(int client, int args) {
  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, true);
  return Plugin_Handled;
}

public Action Command_Disable(int client, int args) {
  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, false);
  return Plugin_Handled;
}

public Action Command_God(int client, int args) {
  if (!GetCvarIntSafe("sv_cheats")) {
    PM_Message(client, ".god 需要开启sv_cheats才可执行");
    return Plugin_Handled;
  }

  FakeClientCommand(client, "god");
  return Plugin_Handled;
}

public Action Command_EndRound(int client, int args) {
  if (!GetCvarIntSafe("sv_cheats")) {
    PM_Message(client, ".endround 需要开启sv_cheats才可执行");
    return Plugin_Handled;
  }

  ServerCommand("endround");
  return Plugin_Handled;
}

public Action Command_Break(int client, int args) {
  int ent = -1;
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    AcceptEntityInput(ent, "Break");
  }
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    AcceptEntityInput(ent, "Break");
  }

  PM_MessageToAll("\x04已破坏所有可破坏的实体");
  return Plugin_Handled;
}
