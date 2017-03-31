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
#include <sdkhooks>
#include <smac>

/* Plugin Info */
public Plugin:myinfo =
{
    name = "SMAC L4D2 Exploit Fixes",
    author = SMAC_AUTHOR,
    description = "Blocks general Left 4 Dead 2 cheats & exploits",
    version = SMAC_VERSION,
    url = SMAC_URL
};

/* Globals */
#define L4D2_ZOMBIECLASS_TANK 8
#define RESET_USE_TIME 0.5
#define RECENT_TEAM_CHANGE_TIME 1.0

new bool:g_bProhibitUse[MAXPLAYERS+1];
new bool:g_didRecentlyChangeTeam[MAXPLAYERS + 1];

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, SMAC_MOD_ERROR);
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public OnPluginStart()
{
    // Hooks.
    HookEvent("player_use", Event_PlayerUse, EventHookMode_Post);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
}

public OnAllPluginsLoaded()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (GetEventBool(event, "disconnect"))
    {
        return;
    }

    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IS_CLIENT(client) || !IsClientInGame(client) || IsFakeClient(client))
    {
        return;
    }

    g_didRecentlyChangeTeam[client] = true;
    CreateTimer(RECENT_TEAM_CHANGE_TIME, Timer_ResetRecentTeamChange, client);
}

public Action:Timer_ResetRecentTeamChange(Handle:timer, any:client)
{
    g_didRecentlyChangeTeam[client] = false;
    return Plugin_Stop;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    // Prevent infected players from killing survivor bots by changing teams in trigger_hurt areas
    if (IS_CLIENT(victim) && g_didRecentlyChangeTeam[victim])
        return Plugin_Handled;

    return Plugin_Continue;
}

public Event_PlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
    new entity = GetEventInt(event, "targetid");

    if (entity <= MaxClients || entity >= MAX_EDICTS || !IsValidEntity(entity))
    {
        return;
    }

    decl String:netclass[16];
    GetEntityNetClass(entity, netclass, 16);

    if (!StrEqual(netclass, "CPistol"))
    {
        return;
    }

    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IS_CLIENT(client) || !IsClientInGame(client) || IsFakeClient(client) || g_bProhibitUse[client])
    {
        return;
    }

    g_bProhibitUse[client] = true;
    CreateTimer(RESET_USE_TIME, Timer_ResetUse, client);
}

public Action:Timer_ResetUse(Handle:timer, any:client)
{
    g_bProhibitUse[client] = false;
    return Plugin_Stop;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    // Block pistol spam.
    if (g_bProhibitUse[client] && (buttons & IN_USE))
    {
        buttons ^= IN_USE;
    }

    // Block tank double-attack.
    if ((buttons & IN_ATTACK) && (buttons & IN_ATTACK2) && 
        GetClientTeam(client) == 3 && IsPlayerAlive(client) && 
        GetEntProp(client, Prop_Send, "m_zombieClass") == L4D2_ZOMBIECLASS_TANK)
    {
        buttons ^= IN_ATTACK2;
    }

    return Plugin_Continue;
}