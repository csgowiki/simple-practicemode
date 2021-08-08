public Action Command_LastGrenade(int client, int args) {
  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
    PM_Message(client, "传送到道具历史记录: %d", index + 1);
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
      PM_Message(client, "传送到道具历史记录: %d",
                 g_GrenadeHistoryIndex[client] + 1);
    } else {
      PM_Message(client, "你的道具历史记录编号为{GREEN} 1 {NORMAL}到 {GREEN}%d{NORMAL}",
                 g_GrenadeHistoryPositions[client].Length);
    }
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    g_GrenadeHistoryIndex[client]--;
    if (g_GrenadeHistoryIndex[client] < 0)
      g_GrenadeHistoryIndex[client] = 0;

    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    PM_Message(client, "传送到道具历史记录: %d",
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
    PM_Message(client, "传送到道具历史记录: %d",
               g_GrenadeHistoryIndex[client] + 1);
  }

  return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  PM_Message(client, "道具记录缓存已清空");

  return Plugin_Handled;
}

public Action Command_Throw(int client, int args) {
  if (!g_CSUtilsLoaded) {
    PM_Message(client, "需要安装csutils插件才能使用该功能");
    return Plugin_Handled;
  }
  if (IsGrenade(g_LastGrenadeType[client])) {
    PM_Message(client, "已重投上次道具");
    CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                      g_LastGrenadeVelocity[client]);
  } else {
    PM_Message(client, "无法重投上一次道具，因为你还没有投掷过");
  }

  return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
  g_TestingFlash[client] = true;
  PM_Message(client, "已保存当前位置。当你投掷闪光弹时，你将会被传送到这里来观察闪光效果");
  PM_Message(client, "输入 {GREEN}.stop {NORMAL}结束闪光测试");
  GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
  GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  return Plugin_Handled;
}

public Action Command_StopFlash(int client, int args) {
  g_TestingFlash[client] = false;
  PM_Message(client, "已禁用闪光测试");
  return Plugin_Handled;
}