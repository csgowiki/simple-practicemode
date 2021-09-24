public Action Command_LastGrenade(int client, int args) {
  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
    PM_Message(client, "传送到道具历史记录: %d", index + 1);
  }

  return Plugin_Handled;
}

public Action Command_SavePos(int client, int args) {
  AddGrenadeToHistory(client);
  PM_Message(client, "已保存当前位置，输入{GREEN} .back {NORMAL}传送.");
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

public Action Command_GotoNade(int client, int args) {
  char arg[GRENADE_ID_LENGTH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    char id[GRENADE_ID_LENGTH];
    if (!FindGrenade(arg, id) || !TeleportToSavedGrenadePosition(client, arg)) {
      PM_Message(client, "不存在的道具编号：%s", arg);
      return Plugin_Handled;
    }
  } else {
    PM_Message(client, "使用方法：{GREEN}.goto <道具编号>{NORMAL}");
  }

  return Plugin_Handled;
}

public Action Command_Grenades(int client, int args) {
  char arg[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
    ArrayList ids = new ArrayList(GRENADE_ID_LENGTH);
    char data[256];
    GrenadeMenuType type = FindGrenades(arg, ids, data, sizeof(data));
    if (type != GrenadeMenuType_Invalid) {
      GiveGrenadeMenu(client, type, 0, data, ids);
    } else {
      PM_Message(client, "没有找到相关道具");
    }
    delete ids;

  } else {
    bool categoriesOnly = (g_SharedAllNadesCvar.IntValue != 0);
    if (categoriesOnly) {
      GiveGrenadeMenu(client, GrenadeMenuType_Categories);
    } else {
      GiveGrenadeMenu(client, GrenadeMenuType_PlayersAndCategories);
    }
  }

  return Plugin_Handled;
}

public Action Command_Find(int client, int args) {
  char arg[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
    GiveGrenadeMenu(client, GrenadeMenuType_MatchingName, 0, arg, null,
                    GrenadeMenuType_MatchingName);
  } else {
    PM_Message(client, "用法：{GREEN} .find <参数>{NORMAL}");
  }

  return Plugin_Handled;
}

public Action Command_RenameGrenade(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));

  UpdateGrenadeName(nadeId, name);
  PM_Message(client, "道具名称已更新");
  return Plugin_Handled;
}

public Action Command_DeleteGrenade(int client, int args) {
  // get the grenade id first
  char grenadeIdStr[32];
  if (args < 1 || !GetCmdArg(1, grenadeIdStr, sizeof(grenadeIdStr))) {
    // if this fails, use the last grenade position
    IntToString(g_CurrentSavedGrenadeId[client], grenadeIdStr, sizeof(grenadeIdStr));
  }

  if (!CanEditGrenade(client, StringToInt(grenadeIdStr))) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  DeleteGrenadeFromKv(grenadeIdStr);
  PM_Message(client, "已删除道具：%s", grenadeIdStr);
  return Plugin_Handled;
}

public Action Command_SaveGrenade(int client, int args) {
  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  TrimString(name);

  if (StrEqual(name, "")) {
    PM_Message(client, "用法： {GREEN}.save <名称> {NORMAL}");
    return Plugin_Handled;
  }

  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
  char grenadeId[GRENADE_ID_LENGTH];
  if (FindGrenadeByName(auth, name, grenadeId)) {
    PM_Message(client, "该名称已经被使用过");
    return Plugin_Handled;
  }

  int max_saved_grenades = g_MaxGrenadesSavedCvar.IntValue;
  if (max_saved_grenades > 0 && CountGrenadesForPlayer(auth) >= max_saved_grenades) {
    PM_Message(client, "你已保存的道具数量已达到上限（%d）",
               max_saved_grenades);
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在玩家飞行过程中无法保存道具");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);

  GrenadeType grenadeType = g_LastGrenadeType[client];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  grenadeOrigin = g_LastGrenadeOrigin[client];
  grenadeVelocity = g_LastGrenadeVelocity[client];

  if (grenadeType != GrenadeType_None && GetVectorDistance(origin, grenadeOrigin) >= 500.0) {
    PM_Message(
        client,
        "{LIGHT_RED}警告：{NORMAL}刚刚保存的道具可能会出现问题。如果 .throw 不能重新投掷，那么请手动重新投掷一次，然后使用 .update更新道具记录");
  }

  Action ret = Plugin_Continue;
  Call_StartForward(g_OnGrenadeSaved);
  Call_PushCell(client);
  Call_PushArray(origin, sizeof(origin));
  Call_PushArray(angles, sizeof(angles));
  Call_PushString(name);
  Call_Finish(ret);

  if (ret < Plugin_Handled) {
    int nadeId =
        SaveGrenadeToKv(client, origin, angles, grenadeOrigin, grenadeVelocity, grenadeType, name);
    g_CurrentSavedGrenadeId[client] = nadeId;
    PM_Message(
        client,
        "道具已保存（编号 %d）。输入{GREEN} .desc <详细描述> {NORMAL}为该道具添加一些描述，或者输入{GREEN} .delete {NORMAL}来删除该道具",
        nadeId);

    if (g_CSUtilsLoaded) {
      if (IsGrenade(g_LastGrenadeType[client])) {
        char grenadeName[64];
        GrenadeTypeString(g_LastGrenadeType[client], grenadeName, sizeof(grenadeName));
        PM_Message(
            client,
            "已保存投掷记录：%s，输入{GREEN} .clearthrow {NORMAL}或{GREEN} .savethrow {NORMAL}来更新投掷记录的参数",
            grenadeName);
      } else {
        PM_Message(client,
                   "未保存投掷记录，输入{GREEN} .savethrow {NORMAL}来保存");
      }
    }
  }

  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_MoveGrenade(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在玩家飞行过程中无法保存道具");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  PM_Message(client, "已更新投掷物参数");
  return Plugin_Handled;
}

public Action Command_SaveThrow(int client, int args) {
  if (!g_CSUtilsLoaded) {
    PM_Message(client, "需要安装csutils插件才能使用该功能");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                             g_LastGrenadeVelocity[client]);
  PM_Message(client, "已更新投掷记录参数");
  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_UpdateGrenade(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "在玩家飞行过程中无法保存道具");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  bool updatedParameters = false;
  if (g_CSUtilsLoaded && IsGrenade(g_LastGrenadeType[client])) {
    updatedParameters = true;
    SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                               g_LastGrenadeVelocity[client]);
  }

  if (updatedParameters) {
    PM_Message(client, "已更新道具位置参数和投掷记录参数");
  } else {
    PM_Message(client, "已更新道具位置参数");
  }

  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_SetDelay(int client, int args) {
  if (!g_CSUtilsLoaded) {
    PM_Message(client, "你需要安装csutils插件才能使用该功能");
    return Plugin_Handled;
  }

  if (args < 1) {
    PM_Message(client, "用法:{GREEN} .delay <延迟秒数> {NORMAL}");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char arg[64];
  GetCmdArgString(arg, sizeof(arg));
  float delay = StringToFloat(arg);
  SetClientGrenadeFloat(nadeId, "delay", delay);
  PM_Message(client, "已保存道具id：%d（延迟%.1f秒）", nadeId, delay);
  return Plugin_Handled;
}

public Action Command_ClearThrow(int client, int args) {
  if (!g_CSUtilsLoaded) {
    PM_Message(client, "你需要安装csutils插件才能使用该功能");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(nadeId, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                             g_LastGrenadeVelocity[client]);
  PM_Message(client, "已清空投掷物参数");
  return Plugin_Handled;
}

public Action Command_GrenadeDescription(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char description[GRENADE_DESCRIPTION_LENGTH];
  GetCmdArgString(description, sizeof(description));

  UpdateGrenadeDescription(nadeId, description);
  PM_Message(client, "已添加道具描述");
  return Plugin_Handled;
}

public Action Command_Categories(int client, int args) {
  GiveGrenadeMenu(client, GrenadeMenuType_Categories);
  return Plugin_Handled;
}

public Action Command_AddCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));
  AddGrenadeCategory(nadeId, category);

  PM_Message(client, "已添加道具仓库");
  return Plugin_Handled;
}

public Action Command_AddCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  for (int i = 1; i <= args; i++) {
    GetCmdArg(i, category, sizeof(category));
    AddGrenadeCategory(nadeId, category);
  }

  PM_Message(client, "已添加道具仓库");
  return Plugin_Handled;
}

public Action Command_RemoveCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "仓库名称不能为空");
    return Plugin_Handled;
  }

  if (RemoveGrenadeCategory(nadeId, category)) {
    PM_Message(client, "已删除道具仓库");
  } else {
    PM_Message(client, "未找到道具仓库");
  }

  return Plugin_Handled;
}

public Action Command_DeleteCategory(int client, int args) {
  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "仓库名称不能为空");
    return Plugin_Handled;
  }

  if (DeleteGrenadeCategory(client, category) > 0) {
    PM_Message(client, "已删除道具仓库");
  } else {
    PM_Message(client, "未找到道具仓库");
  }
  return Plugin_Handled;
}

public Action Command_ClearGrenadeCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "你不是该道具的拥有者");
    return Plugin_Handled;
  }

  SetClientGrenadeData(nadeId, "categories", "");
  PM_Message(client, "已清除道具id：%d的仓库", nadeId);

  return Plugin_Handled;
}