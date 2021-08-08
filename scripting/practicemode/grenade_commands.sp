public Action Command_LastGrenade(int client, int args) {
  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
    PM_Message(client, "Teleporting back to position %d in grenade history.", index + 1);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
  char argString[64];
  if (args >= 1 && GetCmdArg(1, argString, sizeof(argString))) {
    int index = StringToInt(argString) - 1;
    if (index >= 0 && index < g_GrenadeHistoryPositions[client].Length) {
      g_GrenadeHistoryIndex[client] = index;
      TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
      PM_Message(client, "Teleporting back to position %d in grenade history.",
                 g_GrenadeHistoryIndex[client] + 1);
    } else {
      PM_Message(client, "Your grenade history only goes from 1 to %d.",
                 g_GrenadeHistoryPositions[client].Length);
    }
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    g_GrenadeHistoryIndex[client]--;
    if (g_GrenadeHistoryIndex[client] < 0)
      g_GrenadeHistoryIndex[client] = 0;

    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    PM_Message(client, "Teleporting back to position %d in grenade history.",
               g_GrenadeHistoryIndex[client] + 1);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
  if (g_GrenadeHistoryPositions[client].Length > 0) {
    int max = g_GrenadeHistoryPositions[client].Length;
    g_GrenadeHistoryIndex[client]++;
    if (g_GrenadeHistoryIndex[client] >= max)
      g_GrenadeHistoryIndex[client] = max - 1;
    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    PM_Message(client, "Teleporting forward to position %d in grenade history.",
               g_GrenadeHistoryIndex[client] + 1);
  }

  return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  PM_Message(client, "Grenade history cleared.");

  return Plugin_Handled;
}

public Action Command_Throw(int client, int args) {
  if (!g_CSUtilsLoaded) {
    PM_Message(client, "需要安装csutils插件才能使用该功能");
    return Plugin_Handled;
  }
  if (IsGrenade(g_LastGrenadeType[client])) {
    PM_Message(client, "Throwing your last nade.");
    CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                      g_LastGrenadeVelocity[client]);
  } else {
    PM_Message(client, "无法重投上一次道具，因为你还没有投掷过");
  }

  return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
  g_TestingFlash[client] = true;
  PM_Message(
      client,
      "Saved your position. Throw a flashbang and you will be teleported back here to see the flashbang's effect.");
  PM_Message(client, "Use {GREEN}.stop {NORMAL}when you are done testing.");
  GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
  GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  return Plugin_Handled;
}

public Action Command_StopFlash(int client, int args) {
  g_TestingFlash[client] = false;
  PM_Message(client, "Disabled flash testing.");
  return Plugin_Handled;
}

public Action Command_TranslateGrenades(int client, int args) {
  if (args != 3) {
    ReplyToCommand(client, "Usage: sm_translategrenades <dx> <dy> <dz>");
    return Plugin_Handled;
  }

  char buffer[32];
  GetCmdArg(1, buffer, sizeof(buffer));
  float dx = StringToFloat(buffer);

  GetCmdArg(2, buffer, sizeof(buffer));
  float dy = StringToFloat(buffer);

  GetCmdArg(3, buffer, sizeof(buffer));
  float dz = StringToFloat(buffer);

  TranslateGrenades(dx, dy, dz);

  return Plugin_Handled;
}

public Action Command_FixGrenades(int client, int args) {
  CorrectGrenadeIds();
  g_UpdatedGrenadeKv = true;
  ReplyToCommand(client, "Fixed grenade data.");
  return Plugin_Handled;
}
