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