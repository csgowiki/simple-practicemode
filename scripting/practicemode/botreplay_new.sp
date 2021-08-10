public Action Command_BotReplayTest(int client, int args) {
    // ServerCommand("bot_quota_mode normal");
    // ServerCommand("bot_add");

    // CreateTimer(1.0, BotReplayTestTimer, client);


    return Plugin_Handled;
}

// public Action BotReplayTestTimer(Handle timer, int client) {
//     int bot = -1;
//     for (int i = MaxClients; i >= 0; i--) {
//         if (IsValidClient(i) && !IsClientSourceTV(i)) {
//             bot = i;
//             // break;
//         }
//     }
//     PM_MessageToAll("bot: %d", bot);
//     if (bot == -1) {
//         return Plugin_Handled;
//     }
//     SetClientName(bot, "CSGOWiki");

//     int botTeam = GetClientTeam(client) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
//     CS_SwitchTeam(bot, botTeam);


//     CS_RespawnPlayer(bot);
//     DataPack pack = new DataPack();
//     pack.WriteCell(bot);
//     pack.WriteString("addons/sourcemod/test.rec");

//     RequestFrame(StartReplayTest, pack);

//     return Plugin_Handled;
// }


// public void StartReplayTest(DataPack pack) {
//   pack.Reset();
//   int client = pack.ReadCell();
//   char filepath[128];
//   pack.ReadString(filepath, sizeof(filepath));

//   if (g_BotReplayChickenMode) {
//     SetEntityModel(client, CHICKEN_MODEL);
//     SetEntPropFloat(client, Prop_Send, "m_flModelScale", 10.0);
//   }

//   BMError err = BotMimic_PlayRecordFromFile(client, filepath);
//   if (err != BM_NoError) {
//     char errString[128];
//     BotMimic_GetErrorString(err, errString, sizeof(errString));
//     LogError("Error playing record %s on client %d: %s", filepath, client, errString);
//   }

//   delete pack;
// }