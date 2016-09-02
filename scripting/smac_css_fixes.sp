/*
    SourceMod Anti-Cheat
    Copyright (C) 2011-2016 SMAC Development Team 
    Copyright (C) 2007-2011 CodingDirect LLC
   
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>

/* Plugin Info */
public Plugin:myinfo =
{
    name = "SMAC CS:S Exploit Fixes",
    author = SMAC_AUTHOR,
    description = "Blocks general Counter-Strike: Source exploits",
    version = SMAC_VERSION,
    url = SMAC_URL
};

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    if (GetEngineVersion() != Engine_CSS)
    {
        strcopy(error, err_max, SMAC_MOD_ERROR);
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public OnPluginStart()
{
    LoadTranslations("smac.phrases");

    new Handle:hCvar = INVALID_HANDLE;

    hCvar = SMAC_CreateConVar("smac_css_defusefix", "1", "Block illegal defuses.", 0, true, 0.0, true, 1.0);
    OnDefuseFixChanged(hCvar, "", "");
    HookConVarChange(hCvar, OnDefuseFixChanged);

    hCvar = SMAC_CreateConVar("smac_css_respawnfix", "1", "Block players from respawning through rejoins.", 0, true, 0.0, true, 1.0);
    OnRespawnFixChanged(hCvar, "", "");
    HookConVarChange(hCvar, OnRespawnFixChanged);
}

public OnMapStart()
{
    ClearDefuseData();
}

public OnMapEnd()
{
    ClearSpawnData();
}

/**
 * Defuse Fix
 */
new bool:g_bDefuseFixEnabled;
new Float:g_fNextCheck[MAXPLAYERS+1];
new bool:g_bAllowDefuse[MAXPLAYERS+1];

new g_iDefuserEnt = -1;
new Float:g_vBombPos[3];

public OnDefuseFixChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new bool:bNewValue = GetConVarBool(convar);
    if (bNewValue && !g_bDefuseFixEnabled)
    {
        HookEvent("bomb_planted", Event_BombPlanted, EventHookMode_PostNoCopy);
        HookEvent("bomb_begindefuse", Event_BombBeginDefuse, EventHookMode_Post);

        HookEvent("round_start", Event_ResetDefuser, EventHookMode_PostNoCopy);
        HookEvent("bomb_abortdefuse", Event_ResetDefuser, EventHookMode_PostNoCopy);

        BombPlanted();
    }
    else if (!bNewValue && g_bDefuseFixEnabled)
    {
        UnhookEvent("bomb_planted", Event_BombPlanted, EventHookMode_PostNoCopy);
        UnhookEvent("bomb_begindefuse", Event_BombBeginDefuse, EventHookMode_Post);

        UnhookEvent("round_start", Event_ResetDefuser, EventHookMode_PostNoCopy);
        UnhookEvent("bomb_abortdefuse", Event_ResetDefuser, EventHookMode_PostNoCopy);

        ClearDefuseData();
    }
    g_bDefuseFixEnabled = bNewValue;
}

ClearDefuseData()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        g_fNextCheck[i] = 0.0;
    }
    g_iDefuserEnt = -1;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (g_bDefuseFixEnabled && (buttons & IN_USE))
    {
        if (g_fNextCheck[client] > GetGameTime())
        {
            if (!g_bAllowDefuse[client])
            {
                buttons &= ~IN_USE;
            }
        }
        else if (g_iDefuserEnt == client)
        {
            decl Float:vEyePos[3];
            GetClientEyePosition(client, vEyePos);

            TR_TraceRayFilter(vEyePos, g_vBombPos, MASK_VISIBLE, RayType_EndPoint, Filter_WorldOnly);

            g_bAllowDefuse[client] = (TR_GetFraction() == 1.0);
            if (!g_bAllowDefuse[client])
            {
                PrintHintText(client, "%t", "SMAC_IllegalDefuse");
                buttons &= ~IN_USE;
            }
            g_fNextCheck[client] = GetGameTime() + 2.0;
        }
    }

    return Plugin_Continue;
}

public bool:Filter_WorldOnly(entity, mask)
{
    return false;
}

public Event_BombPlanted(Handle:event, const String:name[], bool:dontBroadcast)
{
    BombPlanted();
}

BombPlanted()
{
    new iBombEnt = FindEntityByClassname(-1, "planted_c4");
    if (iBombEnt != -1)
    {
        GetEntPropVector(iBombEnt, Prop_Send, "m_vecOrigin", g_vBombPos);
        g_vBombPos[2] += 5.0;
    }
}

public Event_BombBeginDefuse(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iDefuserEnt = GetClientOfUserId(GetEventInt(event, "userid"));
}

public Event_ResetDefuser(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_iDefuserEnt = -1;
}

/**
 * Respawn Fix
 */
new bool:g_bRespawnFixEnabled;

new Handle:g_hFreezeTime = INVALID_HANDLE;
new Handle:g_hRespawnElapsed = INVALID_HANDLE;
new Handle:g_hClientSpawned = INVALID_HANDLE;
new g_iClientClass[MAXPLAYERS+1] = {-1, ...};

public OnRespawnFixChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (g_hClientSpawned == INVALID_HANDLE)
    {
        g_hClientSpawned = CreateTrie();
    }

    new bool:bNewValue = GetConVarBool(convar);
    if (bNewValue && !g_bRespawnFixEnabled)
    {
        if (g_hFreezeTime == INVALID_HANDLE)
        {
            g_hFreezeTime = FindConVar("mp_freezetime");
        }

        HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

        AddCommandListener(Command_JoinClass, "joinclass");
    }
    else if (!bNewValue && g_bRespawnFixEnabled)
    {
        UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

        RemoveCommandListener(Command_JoinClass, "joinclass");
		
        ClearSpawnData();
    }
    g_bRespawnFixEnabled = bNewValue;
}

public OnClientDisconnect(client)
{
    g_iClientClass[client] = -1;
}

public Action:Command_JoinClass(client, const String:command[], args)
{
    if (!IS_CLIENT(client) || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    // Allow users to join empty teams unhindered.
    new iTeam = GetClientTeam(client);

    if (iTeam > 1 && GetTeamClientCount(iTeam) > 1)
    {
        decl String:sAuthID[MAX_AUTHID_LENGTH], dummy;

        if (GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), false) && GetTrieValue(g_hClientSpawned, sAuthID, dummy))
        {
            decl String:sBuffer[64];
            GetCmdArgString(sBuffer, sizeof(sBuffer));

            if ((g_iClientClass[client] = StringToInt(sBuffer)) < 0)
            {
                g_iClientClass[client] = 0;
            }

            FakeClientCommandEx(client, "spec_mode");
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);

    if (IS_CLIENT(client))
    {
        // Fix for warmup/force respawn plugins
        g_iClientClass[client] = -1;

        // Delay so it doesn't fire before Event_RoundStart
        CreateTimer(0.01, Timer_PlayerSpawned, userid, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:Timer_PlayerSpawned(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (IS_CLIENT(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) > 1)
    {
        decl String:sAuthID[MAX_AUTHID_LENGTH];
        if (GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), false))
        {
            SetTrieValue(g_hClientSpawned, sAuthID, true);
        }
    }

    return Plugin_Stop;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ClearSpawnData();
    g_hRespawnElapsed = CreateTimer(GetConVarFloat(g_hFreezeTime) + 21.0, Timer_RespawnElapsed);
}

public Action:Timer_RespawnElapsed(Handle:timer)
{
    g_hRespawnElapsed = INVALID_HANDLE;
    ClearSpawnData();
    return Plugin_Stop;
}

ClearSpawnData()
{
    ClearTrie(g_hClientSpawned);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_iClientClass[i] != -1)
        {
            if (IsClientInGame(i))
            {
                FakeClientCommandEx(i, "joinclass %d", g_iClientClass[i]);
            }

            g_iClientClass[i] = -1;
        }
    }

    if (g_hRespawnElapsed != INVALID_HANDLE)
    {
        new Handle:hTemp = g_hRespawnElapsed;
        g_hRespawnElapsed = INVALID_HANDLE;

        CloseHandle(hTemp);
    }
}