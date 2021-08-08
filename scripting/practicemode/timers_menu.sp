public Action Command_TimersMenu(int client, int args) {
  Menu menu = new Menu(TimersMenuHandler);
  menu.SetTitle("计时器操作菜单");

  menu.AddItem("timer1", "计时器：玩家移动开始，玩家停止移动结束");
  menu.AddItem("timer2", "计时器：点击开始，再次点击结束");
  menu.AddItem("countdown", "倒计时：玩家移动开始，倒计时归0结束");

  menu.Display(client, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int TimersMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "timer1")) {
      Command_Time(client, 0);
    } else if (StrEqual(buffer, "timer2")) {
      Command_Time2(client, 0);
    } else if (StrEqual(buffer, "countdown")) {
      if (!g_OnCountDownRec[client]) {
          g_OnCountDownRec[client] = true;
        PM_Message(client, "{YELLOW}请在聊天框中输入倒计时秒数，默认为回合秒数。10秒内不输入自动取消{NORMAL}");
        CreateTimer(10.0, Timer_CountDownRec, GetClientSerial(client));
      }
    }

    Command_TimersMenu(client, 0);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action Timer_CountDownRec(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    if (g_OnCountDownRec[client]) {
        g_OnCountDownRec[client] = false;
    }
}
