public Action Command_BotsMenu(int client, int args) {
  Menu menu = new Menu(BotsMenuHandler);
  menu.SetTitle("Bot操作菜单");

  menu.AddItem("place", "在玩家当前位置放置Bot");
  menu.AddItem("crouchplace", "在玩家当前位置放置蹲着的Bot");
  menu.AddItem("bot2", "在玩家准星指向的位置放置Bot");
  menu.AddItem("load", "加载所有已保存的Bot");
  menu.AddItem("save", "保存当前所有的Bot");
  menu.AddItem("clear_bots", "清除所有Bot");
  menu.AddItem("delete", "删除准星指向的Bot");

  menu.Display(client, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int BotsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "place")) {
      Command_Bot(client, 0);
    } else if (StrEqual(buffer, "crouchplace")) {
      Command_CrouchBot(client, 0);
    } else if (StrEqual(buffer, "delete")) {
      Command_RemoveBot(client, 0);
    } else if (StrEqual(buffer, "clear_bots")) {
      Command_RemoveBots(client, 0);
    } else if (StrEqual(buffer, "save")) {
      Command_SaveBots(client, 0);
    } else if (StrEqual(buffer, "load")) {
      Command_LoadBots(client, 0);
    } else if (StrEqual(buffer, "bot2")) {
      Command_BotPlace(client, 0);
    }

    Command_BotsMenu(client, 0);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}
