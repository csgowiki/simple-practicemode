/**
 * Some generic helpers functions.
 */

public bool IsGrenadeProjectile(const char[] className) {
  static char projectileTypes[][] = {
      "hegrenade_projectile", "smokegrenade_projectile", "decoy_projectile",
      "flashbang_projectile", "molotov_projectile",
  };

  return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

stock void TeleportToGrenadeHistoryPosition(int client, int index,
                                            MoveType moveType = MOVETYPE_WALK) {
  float origin[3];
  float angles[3];
  float velocity[3];
  g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
  g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
  TeleportEntity(client, origin, angles, velocity);
  SetEntityMoveType(client, moveType);
}

public void AddGrenadeToHistory(int client) {
  int max_grenades = g_MaxHistorySizeCvar.IntValue;
  if (max_grenades > 0 && GetArraySize(g_GrenadeHistoryPositions[client]) >= max_grenades) {
    RemoveFromArray(g_GrenadeHistoryPositions[client], 0);
    RemoveFromArray(g_GrenadeHistoryAngles[client], 0);
  }

  float position[3];
  float angles[3];
  GetClientAbsOrigin(client, position);
  GetClientEyeAngles(client, angles);
  PushArrayArray(g_GrenadeHistoryPositions[client], position, sizeof(position));
  PushArrayArray(g_GrenadeHistoryAngles[client], angles, sizeof(angles));
  g_GrenadeHistoryIndex[client] = g_GrenadeHistoryPositions[client].Length;
}

public Action TranslateGrenadeHelper(const char[] ownerName, const char[] ownerAuth, const char[] name,
                              const char[] description, ArrayList categories,
                              const char[] grenadeId, float origin[3], float angles[3], any data) {
  DataPack p = view_as<DataPack>(data);
  p.Reset();
  float dx = p.ReadFloat();
  float dy = p.ReadFloat();
  float dz = p.ReadFloat();
  origin[0] += dx;
  origin[1] += dy;
  origin[2] += dz;
}

public bool TeleportToSavedGrenadePosition(int client, const char[] id) {
  float origin[3];
  float angles[3];
  float velocity[3];
  char description[GRENADE_DESCRIPTION_LENGTH];
  char category[GRENADE_CATEGORY_LENGTH];
  bool success = false;
  float delay = 0.0;
  char typeString[32];
  GrenadeType type = GrenadeType_None;

  // Update the client's current grenade id.
  g_CurrentSavedGrenadeId[client] = StringToInt(id);

  char targetAuth[AUTH_LENGTH];
  char targetName[MAX_NAME_LENGTH];
  if (TryJumpToOwnerId(id, targetAuth, sizeof(targetAuth), targetName, sizeof(targetName))) {
    char grenadeName[GRENADE_NAME_LENGTH];
    success = true;
    g_GrenadeLocationsKv.GetVector("origin", origin);
    g_GrenadeLocationsKv.GetVector("angles", angles);
    g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
    g_GrenadeLocationsKv.GetString("description", description, sizeof(description));
    g_GrenadeLocationsKv.GetString("categories", category, sizeof(category));
    g_GrenadeLocationsKv.GetString("grenadeType", typeString, sizeof(typeString));
    type = GrenadeTypeFromString(typeString);
    delay = g_GrenadeLocationsKv.GetFloat("delay");
    TeleportEntity(client, origin, angles, velocity);
    SetEntityMoveType(client, MOVETYPE_WALK);
    PM_Message(client, "传送到道具编号：%s, \"%s\".", id, grenadeName);

    if (!StrEqual(description, "")) {
      PM_Message(client, "Description: %s", description);
    }

    if (!StrEqual(category, "")) {
      ReplaceString(category, sizeof(category), ";", ", ");
      // Cut off the last two characters of the category string to avoid
      // an extraneous comma and space.
      // Only do this for strings sufficiently long, since the data may have been changed by users.
      int len = strlen(category);
      if (len >= 2 && category[len - 2] == ';') {
        category[len - 2] = '\0';
      }
      PM_Message(client, "Categories: %s", category);
    }

    if (delay > 0.0) {
      PM_Message(client, "Grenade delay: %.1f seconds", delay);
    }

    if (type != GrenadeType_None && GetSetting(client, UserSetting_SwitchToNadeOnSelect)) {
      char weaponName[64];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);

      // This is a dirty hack since saved nade data doesn't differentiate between a inc and molotov
      // grenade. See the problem in GrenadeFromProjectileName in csutils.inc. If that is fixed this
      // can be removed.
      if (type == GrenadeType_Molotov) {
        FakeClientCommand(client, "use weapon_incgrenade");
      } else if (type == GrenadeType_Incendiary) {
        FakeClientCommand(client, "use weapon_molotov");
      }
    }

    g_GrenadeLocationsKv.Rewind();
  }

  return success;
}

public int AddCategoriesToList(const char[] categoryString, ArrayList list) {
  const int maxCats = 10;
  const int catSize = 64;
  char parts[maxCats][catSize];
  int foundCats = ExplodeString(categoryString, ";", parts, maxCats, catSize);
  for (int i = 0; i < foundCats; i++) {
    if (!StrEqual(parts[i], ""))
      list.PushString(parts[i]);
  }
  return foundCats;
}

public bool FindId(const char[] idStr, char[] auth, int authLen) {
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, authLen);

      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          char currentId[GRENADE_ID_LENGTH];
          g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
          if (StrEqual(idStr, currentId)) {
            g_GrenadeLocationsKv.Rewind();
            return true;
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }

  return false;
}

public bool FindGrenadeTarget(const char[] nameInput, char[] name, int nameLen, char[] auth, int authLen) {
  int target = AttemptFindTarget(nameInput);
  if (IsPlayer(target) && GetClientAuthId(target, AUTH_METHOD, auth, authLen) &&
      GetClientName(target, name, nameLen)) {
    return true;
  } else {
    return FindTargetInGrenadesKvByName(nameInput, name, nameLen, auth, authLen);
  }
}

public bool FindMatchingCategory(const char[] catinput, char[] output, int length) {
  char[] lastMatching = new char[length];
  int matchingCount = 0;

  for (int i = 0; i < g_KnownNadeCategories.Length; i++) {
    char cat[GRENADE_CATEGORY_LENGTH];
    g_KnownNadeCategories.GetString(i, cat, sizeof(cat));
    if (StrEqual(cat, catinput, false)) {
      strcopy(output, length, cat);
      return true;
    }

    if (StrContains(cat, catinput, false) >= 0) {
      strcopy(lastMatching, length, cat);
      matchingCount++;
    }
  }

  if (matchingCount == 1) {
    strcopy(output, length, lastMatching);
    return true;
  } else {
    return false;
  }
}

public bool TryJumpToId(const char[] idStr) {
  char auth[AUTH_LENGTH];
  if (FindId(idStr, auth, sizeof(auth))) {
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

public bool TryJumpToOwnerId(const char[] idStr, char[] ownerAuth, int authLength, char[] ownerName,
                      int nameLength) {
  if (FindId(idStr, ownerAuth, authLength)) {
    g_GrenadeLocationsKv.JumpToKey(ownerAuth, true);
    g_GrenadeLocationsKv.GetString("name", ownerName, nameLength);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

public bool FindTargetNameByAuth(const char[] inputAuth, char[] name, int nameLen) {
  if (g_GrenadeLocationsKv.JumpToKey(inputAuth, false)) {
    g_GrenadeLocationsKv.GetString("name", name, nameLen);
    g_GrenadeLocationsKv.GoBack();
    return true;
  }
  return false;
}

public bool FindTargetInGrenadesKvByName(const char[] inputName, char[] name, int nameLen, char[] auth,
                                  int authLen) {
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, authLen);
      g_GrenadeLocationsKv.GetString("name", name, nameLen);

      if (StrContains(name, inputName, false) != -1) {
        g_GrenadeLocationsKv.GoBack();
        return true;
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }
  return false;
}

public bool CanEditGrenade(int client, int id) {
  if (!CheckCommandAccess(client, "sm_gotogrenade", ADMFLAG_CHANGEMAP)) {
    return false;
  }

  if (g_SharedAllNadesCvar.IntValue != 0) {
    return true;
  }

  char strId[32];
  IntToString(id, strId, sizeof(strId));
  char clientAuth[AUTH_LENGTH];
  GetClientAuthId(client, AUTH_METHOD, clientAuth, sizeof(clientAuth));
  char ownerAuth[AUTH_LENGTH];
  return FindId(strId, ownerAuth, sizeof(ownerAuth)) && StrEqual(clientAuth, ownerAuth, false);
}

public void UpdateGrenadeName(int id, const char[] name) {
  SetClientGrenadeData(id, "name", name);
}

public void UpdateGrenadeDescription(int id, const char[] description) {
  SetClientGrenadeData(id, "description", description);
}

public void AddGrenadeCategory(int id, const char[] category) {
  char categoryString[GRENADE_CATEGORY_LENGTH];
  GetClientGrenadeData(id, "categories", categoryString, sizeof(categoryString));

  if (StrContains(categoryString, category, false) >= 0) {
    return;
  }

  StrCat(categoryString, sizeof(categoryString), category);
  StrCat(categoryString, sizeof(categoryString), ";");
  SetClientGrenadeData(id, "categories", categoryString);

  CheckNewCategory(category);
}

public bool RemoveGrenadeCategory(int id, const char[] category) {
  char categoryString[GRENADE_CATEGORY_LENGTH];
  GetClientGrenadeData(id, "categories", categoryString, sizeof(categoryString));

  char removeString[GRENADE_CATEGORY_LENGTH];
  Format(removeString, sizeof(removeString), "%s;", category);

  int numreplaced = ReplaceString(categoryString, sizeof(categoryString), removeString, "", false);
  SetClientGrenadeData(id, "categories", categoryString);
  return numreplaced > 0;
}

public int DeleteGrenadeCategory(int client, const char[] category) {
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
  ArrayList ids = new ArrayList();

  char grenadeId[GRENADE_ID_LENGTH];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
          if (CanEditGrenade(client, StringToInt(grenadeId))) {
            ids.Push(StringToInt(grenadeId));
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }
    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }

  int count = 0;
  for (int i = 0; i < ids.Length; i++) {
    if (RemoveGrenadeCategory(ids.Get(i), category)) {
      count++;
    }
  }

  return count;
}

public bool DeleteGrenadeFromKv(const char[] nadeIdStr) {
  g_UpdatedGrenadeKv = true;
  char auth[AUTH_LENGTH];
  FindId(nadeIdStr, auth, sizeof(auth));
  bool deleted = false;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char name[GRENADE_NAME_LENGTH];
    if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
      g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
      g_GrenadeLocationsKv.GoBack();
    }

    deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
    g_GrenadeLocationsKv.GoBack();
  }

  // If the grenade deleted has the highest grenadeId, reset nextid to it so that
  // we don't waste spots in the greandeId-space.
  if (deleted) {
    if (StringToInt(nadeIdStr) + 1 == g_NextID) {
      g_NextID--;
    }
  }

  return deleted;
}

public int CountGrenadesForPlayer(const char[] auth) {
  int count = 0;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        count++;
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return count;
}

stock int SaveGrenadeToKv(int client, const float origin[3], const float angles[3],
                          const float grenadeOrigin[3], const float grenadeVelocity[3],
                          GrenadeType type, const char[] name, const char[] description = "",
                          const char[] categoryString = "") {
  g_UpdatedGrenadeKv = true;
  char idStr[GRENADE_ID_LENGTH];
  IntToString(g_NextID, idStr, sizeof(idStr));

  char auth[AUTH_LENGTH];
  char clientName[MAX_NAME_LENGTH];
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
  GetClientName(client, clientName, sizeof(clientName));
  g_GrenadeLocationsKv.JumpToKey(auth, true);
  g_GrenadeLocationsKv.SetString("name", clientName);

  g_GrenadeLocationsKv.JumpToKey(idStr, true);

  g_GrenadeLocationsKv.SetString("name", name);
  g_GrenadeLocationsKv.SetVector("origin", origin);
  g_GrenadeLocationsKv.SetVector("angles", angles);
  if (g_CSUtilsLoaded && IsGrenade(type)) {
    char grenadeTypeString[32];
    GrenadeTypeString(type, grenadeTypeString, sizeof(grenadeTypeString));
    g_GrenadeLocationsKv.SetString("grenadeType", grenadeTypeString);
    g_GrenadeLocationsKv.SetVector("grenadeOrigin", grenadeOrigin);
    g_GrenadeLocationsKv.SetVector("grenadeVelocity", grenadeVelocity);
  }
  g_GrenadeLocationsKv.SetString("description", description);
  g_GrenadeLocationsKv.SetString("categories", categoryString);

  g_GrenadeLocationsKv.GoBack();
  g_GrenadeLocationsKv.GoBack();
  g_NextID++;
  return g_NextID - 1;
}

public void SetClientGrenadeVectors(int id, const float[3] origin, const float[3] angles) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeVectors(auth, nadeId, origin, angles);
}

public void SetClientGrenadeData(int id, const char[] key, const char[] value) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeData(auth, nadeId, key, value);
}

public void GetClientGrenadeData(int id, const char[] key, char[] value, int valueLength) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  GetGrenadeData(auth, nadeId, key, value, valueLength);
}

public void CheckNewCategory(const char[] cat) {
  if (!StrEqual(cat, "") &&
      FindStringInList(g_KnownNadeCategories, GRENADE_CATEGORY_LENGTH, cat, false) == -1) {
    g_KnownNadeCategories.PushString(cat);
    SortADTArray(g_KnownNadeCategories, Sort_Ascending, Sort_String);
  }
}

public void SetGrenadeData(const char[] auth, const char[] id, const char[] key, const char[] value) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetString(key, value);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetGrenadeVectors(const char[] auth, const char[] id, const float[3] origin,
                       const float[3] angles) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetVector("origin", origin);
      g_GrenadeLocationsKv.SetVector("angles", angles);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void GetGrenadeData(const char[] auth, const char[] id, const char[] key, char[] value,
                    int valueLength) {
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetString(key, value, valueLength);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}