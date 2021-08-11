public Action Command_BotReplayTest(int client, int args) {
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");

    CreateTimer(1.0, BotReplayTestTimer, client);

    return Plugin_Handled;
}

public Action Command_StartRecord(int client, int args) {
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }
    if(BotMimic_IsPlayerMimicing(client)) {
        PM_Message(client, "{LIGHT_RED}你正在录像{NORMAL}");
        return Plugin_Handled;
    }
    PM_Message(client, "{GREEN}开始录像{NORMAL}");
    BotMimic_StartRecording(client, "hello", "new");
    return Plugin_Handled;
}

public Action Command_StopRecord(int client, int args) {
	if(!IsValidClient(client)) {
		return Plugin_Handled;
    }
	if(!BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "{LIGHT_RED}你开没有开始录像{NORMAL}");
		return Plugin_Handled;
	}
    PM_Message(client, "{DARK_RED}停止录像{NORMAL}");
	BotMimic_StopRecording(client, true);
	return Plugin_Handled;
}

public Action BotReplayTestTimer(Handle timer, int client) {
    int bot = -1;
    for (int i = MaxClients; i >= 0; i--) {
        if (IsValidClient(i) && !IsClientSourceTV(i)) {
            bot = i;
            // break;
        }
    }
    PM_MessageToAll("bot: %d", bot);
    if (bot == -1) {
        return Plugin_Handled;
    }
    SetClientName(bot, "CSGOWiki");

    int botTeam = GetClientTeam(client) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
    CS_SwitchTeam(bot, botTeam);


    CS_RespawnPlayer(bot);
    DataPack pack = new DataPack();
    pack.WriteCell(bot);
    pack.WriteString("addons/sourcemod/data/botmimic/new/de_inferno/1628656577.rec");

    RequestFrame(StartReplayTest, pack);

    return Plugin_Handled;
}


public void StartReplayTest(DataPack pack) {
    pack.Reset();
    int client = pack.ReadCell();
    char filepath[128];
    pack.ReadString(filepath, sizeof(filepath));

    bool g_BotReplayChickenMode = false;
    if (g_BotReplayChickenMode) {
        SetEntityModel(client, CHICKEN_MODEL);
        SetEntPropFloat(client, Prop_Send, "m_flModelScale", 10.0);
    }

    BMError err = BotMimic_PlayRecordFromFile(client, filepath);
    if (err != BM_NoError) {
        char errString[128];
        BotMimic_GetErrorString(err, errString, sizeof(errString));
        LogError("Error playing record %s on client %d: %s", filepath, client, errString);
    }

    delete pack;
}