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

//--------------------------- NOTICE: README -----------------------------//
// As of latest 0.8.6.0 version of SMAC, CS:GO is no longer supported due 
// to the inclusion of the "sv_occlude_players" server variable added by Valve.
// I have opted to leave the code in, but I have commented it out. 
// If you wish to use this code (for whatever reason) uncomment it and
// recompile the plugin yourself.
//------------------------------------------------------------------------//

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smac>

/* Plugin Info */
public Plugin:myinfo =
{
    name = "SMAC Anti-Wallhack",
    author = SMAC_AUTHOR,
    description = "Prevents wallhack cheats from working",
    version = SMAC_VERSION,
    url = SMAC_URL
};

/* Globals */
//#define SND_UNKNOWN_CSGO_FLAG1	(1 << 10)
//#define SND_UNKNOWN_CSGO_FLAG2	(1 << 11)

new GameType:g_Game = Game_Unknown;

new bool:g_bEnabled, bool:g_bFarEspEnabled;
new g_iMaxTraces;

new g_iDownloadTable = INVALID_STRING_TABLE;
new Handle:g_hIgnoreSounds = INVALID_HANDLE;

new g_iPVSCache[MAXPLAYERS+1][MAXPLAYERS+1];
new g_iPVSSoundCache[MAXPLAYERS+1][MAXPLAYERS+1];
new bool:g_bIsVisible[MAXPLAYERS+1][MAXPLAYERS+1];
new bool:g_bIsObserver[MAXPLAYERS+1];
new bool:g_bIsFake[MAXPLAYERS+1];
new bool:g_bProcess[MAXPLAYERS+1];
new bool:g_bIgnore[MAXPLAYERS+1];
new bool:g_bForceIgnore[MAXPLAYERS+1];

new g_iWeaponOwner[MAX_EDICTS];
new g_iTeam[MAXPLAYERS+1];
new Float:g_vMins[MAXPLAYERS+1][3];
new Float:g_vMaxs[MAXPLAYERS+1][3];
new Float:g_vAbsCentre[MAXPLAYERS+1][3];
new Float:g_vEyePos[MAXPLAYERS+1][3];
new Float:g_vEyeAngles[MAXPLAYERS+1][3];

new g_iTotalThreads = 1, g_iCurrentThread = 1, g_iThread[MAXPLAYERS+1] = { 1, ... };
new g_iCacheTicks, g_iTraceCount;
new g_iTickCount, g_iCmdTickCount[MAXPLAYERS+1], g_iTickRate;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    if (GetEngineVersion() == Engine_CSGO)
    {
        strcopy(error, err_max, "This module is disabled for this game. Enable \"sv_occlude_players\" for the same feature.");
        return APLRes_Failure;
    }

    CreateNative("SMAC_WH_SetClientIgnore", Native_SetClientIgnore);
    CreateNative("SMAC_WH_GetClientIgnore", Native_GetClientIgnore);

    RegPluginLibrary("smac_wallhack");

    return APLRes_Success;
}

public OnPluginStart()
{
    // Convars.
    new Handle:hCvar = INVALID_HANDLE;

    hCvar = SMAC_CreateConVar("smac_wallhack", "1", "Enable Anti-Wallhack. This will increase your server's CPU usage.", 0, true, 0.0, true, 1.0);
    OnSettingsChanged(hCvar, "", "");
    HookConVarChange(hCvar, OnSettingsChanged);

    hCvar = CreateConVar("smac_wallhack_maxtraces", "1280", "Max amount of traces that can be executed in one tick.", 0, true, 1.0);
    OnMaxTracesChanged(hCvar, "", "");
    HookConVarChange(hCvar, OnMaxTracesChanged);

    // Clients use these for prediction. Only change cvars if they aren't in the server's config.
    g_iTickRate = RoundToFloor(1.0 / GetTickInterval());

    if ((hCvar = FindConVar("sv_minupdaterate")) != INVALID_HANDLE && IsConVarDefault(hCvar))
        SetConVarInt(hCvar, g_iTickRate);
    if ((hCvar = FindConVar("sv_maxupdaterate")) != INVALID_HANDLE && IsConVarDefault(hCvar))
        SetConVarInt(hCvar, g_iTickRate);
    if ((hCvar = FindConVar("sv_client_min_interp_ratio")) != INVALID_HANDLE && IsConVarDefault(hCvar))
        SetConVarInt(hCvar, 0);
    if ((hCvar = FindConVar("sv_client_max_interp_ratio")) != INVALID_HANDLE && IsConVarDefault(hCvar))
        SetConVarInt(hCvar, 1);
	
    // Initialize.
    g_Game = SMAC_GetGameType();
    g_iDownloadTable = FindStringTable("downloadables");
    g_iCacheTicks = TIME_TO_TICK(0.75);

    RequireFeature(FeatureType_Capability, FEATURECAP_PLAYERRUNCMD_11PARAMS, "This module requires a newer version of SourceMod.");

    for (new i = 0; i < sizeof(g_bIsVisible); i++)
    {
        for (new j = 0; j < sizeof(g_bIsVisible[]); j++)
        {
            g_bIsVisible[i][j] = true;
        }
    }

    // Default sounds to ignore in sound hook.
    g_hIgnoreSounds = CreateTrie();
    SetTrieValue(g_hIgnoreSounds, "buttons/button14.wav", 1);
    SetTrieValue(g_hIgnoreSounds, "buttons/combine_button7.wav", 1);

    switch (g_Game)
    {
        case Game_L4D2:
        {
            SetTrieValue(g_hIgnoreSounds, "UI/Pickup_GuitarRiff10.wav", 1);
        }
    }
}

// native SMAC_WH_SetClientIgnore(client, bool:bIgnore);
public Native_SetClientIgnore(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);

    if (!IS_CLIENT(client) || !IsClientInGame(client))
    {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
    }

    g_bForceIgnore[client] = bool:GetNativeCell(2);
    Wallhack_UpdateClientCache(client);
}

// native bool:SMAC_WH_GetClientIgnore(client);
public Native_GetClientIgnore(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);

    if (!IS_CLIENT(client) || !IsClientConnected(client))
    {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
    }

    return g_bIgnore[client];
}

public OnConfigsExecuted()
{
    // Ignore all sounds in the download table.
    if (g_iDownloadTable == INVALID_STRING_TABLE)
        return;

    decl String:sBuffer[PLATFORM_MAX_PATH];
    new iMaxStrings = GetStringTableNumStrings(g_iDownloadTable);

    for (new i = 0; i < iMaxStrings; i++)
    {
        ReadStringTable(g_iDownloadTable, i, sBuffer, sizeof(sBuffer));

        if (strncmp(sBuffer, "sound", 5) == 0)
        {
            SetTrieValue(g_hIgnoreSounds, sBuffer[6], 1);
        }
    }
}

public OnClientPutInServer(client)
{
    if (g_bEnabled)
    {
        Wallhack_Hook(client);
        Wallhack_UpdateClientCache(client);
    }
}

public OnClientDisconnect(client)
{
    // Stop checking clients right before they disconnect.
    g_bIsObserver[client] = false;
    g_bProcess[client] = false;
    g_bIgnore[client] = false;
    g_bForceIgnore[client] = false;
}

public OnClientDisconnect_Post(client)
{
    // Clear cache on post to ensure it's not updated again.
    for (new i = 0; i < sizeof(g_iPVSCache); i++)
    {
        g_iPVSCache[i][client] = 0;
        g_iPVSSoundCache[i][client] = 0;
        g_bIsVisible[i][client] = true;
    }
}

public Event_PlayerStateChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Not all data has been updated at this time. Wait until the next tick to update cache.
    CreateTimer(0.001, Timer_PlayerStateChanged, GetEventInt(event, "userid"), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_PlayerStateChanged(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (IS_CLIENT(client) && IsClientInGame(client))
    {
        Wallhack_UpdateClientCache(client);
    }

    return Plugin_Stop;
}

Wallhack_UpdateClientCache(client)
{
    g_iTeam[client] = GetClientTeam(client);
    g_bIsObserver[client] = IsClientObserver(client);
    g_bIsFake[client] = IsFakeClient(client);
    g_bProcess[client] = IsPlayerAlive(client);

    // Clients that should not be tested for visibility.
    g_bIgnore[client] = g_bForceIgnore[client] || g_bIsFake[client] || ((g_Game == Game_L4D || g_Game == Game_L4D2 || g_Game == Game_HIDDEN) && g_iTeam[client] != 2);
}

public OnSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new bool:bNewValue = GetConVarBool(convar);

    if (bNewValue && !g_bEnabled)
    {
        Wallhack_Enable();
    }
    else if (!bNewValue && g_bEnabled)
    {
        Wallhack_Disable();
    }
}

public OnMaxTracesChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_iMaxTraces = GetConVarInt(convar);
}

Wallhack_Enable()
{
    g_bEnabled = true;

    AddNormalSoundHook(Hook_NormalSound);

    HookEvent("player_spawn", Event_PlayerStateChanged, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerStateChanged, EventHookMode_Post);
    HookEvent("player_team", Event_PlayerStateChanged, EventHookMode_Post);

    switch (g_Game)
    {
        case Game_TF2:
        {
            HookEntityOutput("item_teamflag", "OnPickUp", TF2_Hook_FlagEquip);
            HookEntityOutput("item_teamflag", "OnDrop", TF2_Hook_FlagDrop);
            HookEntityOutput("item_teamflag", "OnReturn", TF2_Hook_FlagDrop);
            HookEvent("post_inventory_application", TF2_Event_Inventory, EventHookMode_Post);
        }
        case Game_CSS:
        {
            FarESP_Enable();
        }
        case Game_L4D, Game_L4D2:
        {
            HookEvent("player_first_spawn", Event_PlayerStateChanged, EventHookMode_Post);
            HookEvent("ghost_spawn_time", L4D_Event_GhostSpawnTime, EventHookMode_Post);
        }
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            Wallhack_Hook(i);
            Wallhack_UpdateClientCache(i);
        }
    }
    
    new maxEdicts = GetEntityCount();
    for (new i = MaxClients + 1; i < maxEdicts; i++)
    {
        if (IsValidEdict(i))
        {
            new owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");

            if (IS_CLIENT(owner))
            {
                g_iWeaponOwner[i] = owner;
                SDKHook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
            }
        }
    }
}

Wallhack_Disable()
{
    g_bEnabled = false;

    RemoveNormalSoundHook(Hook_NormalSound);

    UnhookEvent("player_spawn", Event_PlayerStateChanged, EventHookMode_Post);
    UnhookEvent("player_death", Event_PlayerStateChanged, EventHookMode_Post);
    UnhookEvent("player_team", Event_PlayerStateChanged, EventHookMode_Post);
    
    switch (g_Game)
    {
        case Game_TF2:
        {
            UnhookEntityOutput("item_teamflag", "OnPickUp", TF2_Hook_FlagEquip);
            UnhookEntityOutput("item_teamflag", "OnDrop", TF2_Hook_FlagDrop);
            UnhookEntityOutput("item_teamflag", "OnReturn", TF2_Hook_FlagDrop);
            UnhookEvent("post_inventory_application", TF2_Event_Inventory, EventHookMode_Post);
        }
        case Game_CSS:
        {
            FarESP_Disable();
        }
        case Game_L4D, Game_L4D2:
        {
            UnhookEvent("player_first_spawn", Event_PlayerStateChanged, EventHookMode_Post);
            UnhookEvent("ghost_spawn_time", L4D_Event_GhostSpawnTime, EventHookMode_Post);
        }
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            Wallhack_Unhook(i);
        }
    }

    new maxEdicts = GetEntityCount();
    for (new i = MaxClients + 1; i < maxEdicts; i++)
    {
        if (g_iWeaponOwner[i])
        {
            g_iWeaponOwner[i] = 0;
            SDKUnhook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
        }
    }
}

/**
 * Hooks
 */
Wallhack_Hook(client)
{
    SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
    SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
    SDKHook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost);
}

Wallhack_Unhook(client)
{
    SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
    SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
    SDKUnhook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost);
}

public OnEntityCreated(entity, const String:classname[])
{
    if (entity > MaxClients && entity < MAX_EDICTS)
    {
        g_iWeaponOwner[entity] = 0;
    }
}

public OnEntityDestroyed(entity)
{
    if (entity > MaxClients && entity < MAX_EDICTS)
    {
        g_iWeaponOwner[entity] = 0;
    }
}

public Hook_WeaponEquipPost(client, weapon)
{
    if (weapon > MaxClients && weapon < MAX_EDICTS)
    {
        g_iWeaponOwner[weapon] = client;
        SDKHook(weapon, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
    }
}

public Hook_WeaponDropPost(client, weapon)
{
    if (weapon > MaxClients && weapon < MAX_EDICTS)
    {
        g_iWeaponOwner[weapon] = 0;
        SDKUnhook(weapon, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
    }
}

public Action:Hook_NormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    /* Emit sounds to clients who aren't being transmitted the entity. */
    decl dummy;

    if (!entity || !IsValidEdict(entity) || GetTrieValue(g_hIgnoreSounds, sample, dummy))
        return Plugin_Continue;

    new iOwner = (entity > MaxClients) ? g_iWeaponOwner[entity] : entity;
	
    if (!IS_CLIENT(iOwner))
        return Plugin_Continue;

    //// CSGO added new sound flags that aren't compatible with this module.
    //if (g_Game == Game_CSGO)
    //{
    //    // Seems to only be used by voice commands.
    //    if (flags & SND_UNKNOWN_CSGO_FLAG2)
    //        return Plugin_Continue;

    //    flags &= ~SND_UNKNOWN_CSGO_FLAG1;
    //}

    decl newClients[MaxClients];
    new bool:bAddClient[MaxClients+1], newTotal;

    // Check clients that get the sound by default.
    for (new i = 0; i < numClients; i++)
    {
        new client = clients[i];

        // SourceMod and game engine don't always agree.
        if (!IsClientInGame(client))
            continue;

        // These clients need the entity information for prediction.
        if (g_bIsFake[client] || client == iOwner)
        {
            newClients[newTotal++] = client;
            continue;
        }

        // Body sounds (footsteps, jumping, etc) will be kept strict to the PVS because they're quiet anyway.
        // Weapons can be heard from larger distances.
        if (channel == SNDCHAN_BODY)
            bAddClient[client] = g_bIsVisible[iOwner][client];
        else
            bAddClient[client] = true;
    }

    // Emit with entity information.
    if (newTotal)
    {
        EmitSound(newClients, newTotal, sample, entity, channel, level, flags, volume, pitch);
        newTotal = 0;
    }

    // Determine which clients still need this sound.
    for (new i = 1; i <= MaxClients; i++)
    {
        // A client in the PVS will be expected to predict the sound even if we're blocking transmit.
        if (bAddClient[i] || ((g_bProcess[i] || g_bIsObserver[i]) && !g_bIsVisible[iOwner][i] && g_iPVSSoundCache[iOwner][i] > g_iTickCount))
        {
            newClients[newTotal++] = i;
        }
    }

    // Emit without entity information.
    if (newTotal)
    {
        decl Float:vOrigin[3];
        GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
        EmitSound(newClients, newTotal, sample, SOUND_FROM_WORLD, channel, level, flags, volume, pitch, _, vOrigin);
    }

    return Plugin_Stop;
}

public TF2_Hook_FlagEquip(const String:output[], caller, activator, Float:delay)
{
    if (caller > MaxClients && caller < MAX_EDICTS && IS_CLIENT(activator) && IsClientConnected(activator))
    {
        g_iWeaponOwner[caller] = activator;
        SDKHook(caller, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
    }
}

public TF2_Hook_FlagDrop(const String:output[], caller, activator, Float:delay)
{
    if (caller > MaxClients && caller < MAX_EDICTS)
    {
        g_iWeaponOwner[caller] = 0;
        SDKUnhook(caller, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
    }
}

public TF2_Event_Inventory(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IS_CLIENT(client))
    {
        new maxEdicts = GetEntityCount();
        for (new i = MaxClients + 1; i < maxEdicts; i++)
        {
            if (IsValidEdict(i) && GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == client)
            {
                g_iWeaponOwner[i] = client;
                SDKHook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
            }
        }
    }
}

public L4D_Event_GhostSpawnTime(Handle:event, const String:name[], bool:dontBroadcast)
{
    // There is no event for observer -> ghost mode, so we must count it down ourselves.
    CreateTimer(GetEventInt(event, "spawntime") + 0.5, Timer_PlayerStateChanged, GetEventInt(event, "userid"), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * OnGameFrame
 */
public OnGameFrame()
{
    if (!g_bEnabled)
        return;

    g_iTickCount = GetGameTickCount();

    // Increment to next thread.
    if (++g_iCurrentThread > g_iTotalThreads)
    {
        g_iCurrentThread = 1;

        // Reassign threads
        if (g_iTraceCount)
        {
            // Calculate total needed threads for the next pass.
            g_iTotalThreads = g_iTraceCount / g_iMaxTraces + 1;

            // Assign each client to a thread.
            new iThreadAssign = 1;

            for (new i = 1; i <= MaxClients; i++)
            {
                if (g_bProcess[i])
                {
                    g_iThread[i] = iThreadAssign;

                    if (++iThreadAssign > g_iTotalThreads)
                    {
                        iThreadAssign = 1;
                    }
                }
            }

            g_iTraceCount = 0;
        }
    }

    if (g_bFarEspEnabled)
    {
        FarESP_OnGameFrame();
    }
}

public Action:Hook_SetTransmit(entity, client)
{
    static iLastChecked[MAXPLAYERS+1][MAXPLAYERS+1];

    // Cache PVS for sound hook.
    g_iPVSSoundCache[entity][client] = g_iTickCount + g_iCacheTicks;

    // Data is transmitted multiple times per tick. Only run calculations once.
    if (iLastChecked[entity][client] == g_iTickCount)
    {
        return g_bIsVisible[entity][client] ? Plugin_Continue : Plugin_Handled;
    }

    iLastChecked[entity][client] = g_iTickCount;

    if (g_bProcess[client])
    {
        if (g_bProcess[entity] && g_iTeam[client] != g_iTeam[entity] && !g_bIgnore[client])
        {
            if (g_iThread[client] == g_iCurrentThread)
            {
                // Grab client data before running traces.
                UpdateClientData(client);
                UpdateClientData(entity);

                if (IsAbleToSee(entity, client))
                {
                    g_bIsVisible[entity][client] = true;
                    g_iPVSCache[entity][client] = g_iTickCount + g_iCacheTicks;
                }
                else if (g_iTickCount > g_iPVSCache[entity][client])
                {
                    g_bIsVisible[entity][client] = false;
                }
            }
        }
        else
        {
            g_bIsVisible[entity][client] = true;
        }
    }
    else if (!g_bIsFake[client] && g_bProcess[entity] && GetClientObserverMode(client) == OBS_MODE_IN_EYE)
    {
        // Observers in first-person will clone the visiblity of their target.
        new iTarget = GetClientObserverTarget(client);
        
        if (IS_CLIENT(iTarget))
        {
            g_bIsVisible[entity][client] = g_bIsVisible[entity][iTarget];
        }
        else
        {
            g_bIsVisible[entity][client] = true;
        }
    }
    else
    {
        g_bIsVisible[entity][client] = true;
    }

    return g_bIsVisible[entity][client] ? Plugin_Continue : Plugin_Handled;
}

public Action:Hook_SetTransmitWeapon(entity, client)
{
    return g_bIsVisible[g_iWeaponOwner[entity]][client] ? Plugin_Continue : Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
    if (!g_bEnabled || !g_bProcess[client])
        return Plugin_Continue;

    g_vEyeAngles[client] = angles;
    g_iCmdTickCount[client] = tickcount;

    return Plugin_Continue;
}

UpdateClientData(client)
{
    /* Only update client data once per tick. */
    static iLastCached[MAXPLAYERS+1];

    if (iLastCached[client] == g_iTickCount)
        return;

    iLastCached[client] = g_iTickCount;

    GetClientMins(client, g_vMins[client]);
    GetClientMaxs(client, g_vMaxs[client]);
    GetClientAbsOrigin(client, g_vAbsCentre[client]);
    GetClientEyePosition(client, g_vEyePos[client]);

    // Adjust vectors relative to the model's absolute centre.
    g_vMaxs[client][2] /= 2.0;
    g_vMins[client][2] -= g_vMaxs[client][2];
    g_vAbsCentre[client][2] += g_vMaxs[client][2];

    // Adjust vectors based on the clients velocity.
    decl Float:vVelocity[3];
    GetClientAbsVelocity(client, vVelocity);
    
    if (!IsVectorZero(vVelocity))
    {
        // Lag compensation.
        decl iTargetTick;

        if (g_bIsFake[client])
        {
            iTargetTick = g_iTickCount - 1;
        }
        else
        {
            // Based on CLagCompensationManager::StartLagCompensation.
            new Float:fCorrect = GetClientLatency(client, NetFlow_Outgoing);
            new iLerpTicks = TIME_TO_TICK(GetEntPropFloat(client, Prop_Data, "m_fLerpTime"));

            // Assume sv_maxunlag == 1.0f seconds.
            fCorrect += TICK_TO_TIME(iLerpTicks);
            fCorrect = ClampValue(fCorrect, 0.0, 1.0);

            iTargetTick = g_iCmdTickCount[client] - iLerpTicks;

            if (FloatAbs(fCorrect - TICK_TO_TIME(g_iTickCount - iTargetTick)) > 0.2)
            {
                // Difference between cmd time and latency is too big > 200ms.
                // Use time correction based on latency.
                iTargetTick = g_iTickCount - TIME_TO_TICK(fCorrect);
            }
        }

        // Use velocity before it's modified.
        decl Float:vTemp[3];
        vTemp[0] = FloatAbs(vVelocity[0]) * 0.01;
        vTemp[1] = FloatAbs(vVelocity[1]) * 0.01;
        vTemp[2] = FloatAbs(vVelocity[2]) * 0.01;

        // Calculate predicted positions for the next frame.
        decl Float:vPredicted[3];
        ScaleVector(vVelocity, TICK_TO_TIME((g_iTickCount - iTargetTick) * g_iTotalThreads));
        AddVectors(g_vAbsCentre[client], vVelocity, vPredicted);

        // Make sure the predicted position is still inside the world.
        TR_TraceHullFilter(vPredicted, vPredicted, Float:{-5.0, -5.0, -5.0}, Float:{5.0, 5.0, 5.0}, MASK_PLAYERSOLID_BRUSHONLY, Filter_WorldOnly);
        g_iTraceCount++;

        if (!TR_DidHit())
        {
            g_vAbsCentre[client] = vPredicted;
            AddVectors(g_vEyePos[client], vVelocity, g_vEyePos[client]);
        }

        // Expand the mins/maxs to help smooth during fast movement.
        if (vTemp[0] > 1.0)
        {
            g_vMins[client][0] *= vTemp[0];
            g_vMaxs[client][0] *= vTemp[0];
        }
        if (vTemp[1] > 1.0)
        {
            g_vMins[client][1] *= vTemp[1];
            g_vMaxs[client][1] *= vTemp[1];
        }
        if (vTemp[2] > 1.0)
        {
            g_vMins[client][2] *= vTemp[2];
            g_vMaxs[client][2] *= vTemp[2];
        }
    }
}

/**
 * Calculations
 */
bool:IsAbleToSee(entity, client)
{
    // Game specific checks.
    switch (g_Game)
    {
        case Game_L4D2:
        {
            if (L4D_IsPlayerGhost(entity))
                return false;

            if (L4D2_IsInfectedBusy(entity) || L4D2_IsSurvivorBusy(client))
                return true;
        }
        case Game_L4D:
        {
            if (L4D_IsPlayerGhost(entity))
                return false;

            if (L4D_IsInfectedBusy(entity) || L4D_IsSurvivorBusy(client))
                return true;
        }
    }

    // Skip all traces if the player isn't within the field of view.
    if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
    {
        // Check if centre is visible.
        if (IsPointVisible(g_vEyePos[client], g_vAbsCentre[entity]))
            return true;

        // Check if weapon tip is visible.
        if (IsFwdVecVisible(g_vEyePos[client], g_vEyeAngles[entity], g_vEyePos[entity]))
            return true;

        // Check outer 4 corners of player.
        if (IsRectangleVisible(g_vEyePos[client], g_vAbsCentre[entity], g_vMins[entity], g_vMaxs[entity], 1.30))
            return true;

        // Check inner 4 corners of player.
        if (IsRectangleVisible(g_vEyePos[client], g_vAbsCentre[entity], g_vMins[entity], g_vMaxs[entity], 0.65))
            return true;
    }
    
    return false;
}

bool:IsInFieldOfView(const Float:start[3], const Float:angles[3], const Float:end[3])
{
    decl Float:normal[3], Float:plane[3];

    GetAngleVectors(angles, normal, NULL_VECTOR, NULL_VECTOR);
    SubtractVectors(end, start, plane);
    NormalizeVector(plane, plane);
    
    return GetVectorDotProduct(plane, normal) > 0.0; // Cosine(Deg2Rad(179.9 / 2.0))
}

public bool:Filter_WorldOnly(entity, mask)
{
    return false;
}

public bool:Filter_NoPlayers(entity, mask)
{
    return entity > MaxClients && !IS_CLIENT(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity"));
}

bool:IsPointVisible(const Float:start[3], const Float:end[3])
{
    // TF2's team-specific barriers don't have a suitable workaround.
    if (g_Game == Game_TF2 || g_Game == Game_HIDDEN)
        TR_TraceRayFilter(start, end, MASK_VISIBLE, RayType_EndPoint, Filter_WorldOnly);
    else
        TR_TraceRayFilter(start, end, MASK_VISIBLE, RayType_EndPoint, Filter_NoPlayers);

    g_iTraceCount++;

    return TR_GetFraction() == 1.0;
}

bool:IsFwdVecVisible(const Float:start[3], const Float:angles[3], const Float:end[3])
{
    decl Float:fwd[3];

    GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(fwd, 50.0);
    AddVectors(end, fwd, fwd);

    return IsPointVisible(start, fwd);
}

bool:IsRectangleVisible(const Float:start[3], const Float:end[3], const Float:mins[3], const Float:maxs[3], Float:scale=1.0)
{
    new Float:ZpozOffset = maxs[2];
    new Float:ZnegOffset = mins[2];
    new Float:WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

    // This rectangle is just a point!
    if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0)
    {
        return IsPointVisible(start, end);
    }

    // Adjust to scale.
    ZpozOffset *= scale;
    ZnegOffset *= scale;
    WideOffset *= scale;

    // Prepare rotation matrix.
    decl Float:angles[3], Float:fwd[3], Float:right[3];

    SubtractVectors(start, end, fwd);
    NormalizeVector(fwd, fwd);

    GetVectorAngles(fwd, angles);
    GetAngleVectors(angles, fwd, right, NULL_VECTOR);

    decl Float:vRectangle[4][3], Float:vTemp[3];

    // If the player is on the same level as us, we can optimize by only rotating on the z-axis.
    if (FloatAbs(fwd[2]) <= 0.7071)
    {
        ScaleVector(right, WideOffset);

        // Corner 1, 2
        vTemp = end;
        vTemp[2] += ZpozOffset;
        AddVectors(vTemp, right, vRectangle[0]);
        SubtractVectors(vTemp, right, vRectangle[1]);

        // Corner 3, 4
        vTemp = end;
        vTemp[2] += ZnegOffset;
        AddVectors(vTemp, right, vRectangle[2]);
        SubtractVectors(vTemp, right, vRectangle[3]);

    }
    else if (fwd[2] > 0.0) // Player is below us.
    {
        fwd[2] = 0.0;
        NormalizeVector(fwd, fwd);

        ScaleVector(fwd, scale);
        ScaleVector(fwd, WideOffset);
        ScaleVector(right, WideOffset);

        // Corner 1
        vTemp = end;
        vTemp[2] += ZpozOffset;
        AddVectors(vTemp, right, vTemp);
        SubtractVectors(vTemp, fwd, vRectangle[0]);

        // Corner 2
        vTemp = end;
        vTemp[2] += ZpozOffset;
        SubtractVectors(vTemp, right, vTemp);
        SubtractVectors(vTemp, fwd, vRectangle[1]);

        // Corner 3
        vTemp = end;
        vTemp[2] += ZnegOffset;
        AddVectors(vTemp, right, vTemp);
        AddVectors(vTemp, fwd, vRectangle[2]);

        // Corner 4
        vTemp = end;
        vTemp[2] += ZnegOffset;
        SubtractVectors(vTemp, right, vTemp);
        AddVectors(vTemp, fwd, vRectangle[3]);
    }
    else // Player is above us.
    {
        fwd[2] = 0.0;
        NormalizeVector(fwd, fwd);

        ScaleVector(fwd, scale);
        ScaleVector(fwd, WideOffset);
        ScaleVector(right, WideOffset);

        // Corner 1
        vTemp = end;
        vTemp[2] += ZpozOffset;
        AddVectors(vTemp, right, vTemp);
        AddVectors(vTemp, fwd, vRectangle[0]);

        // Corner 2
        vTemp = end;
        vTemp[2] += ZpozOffset;
        SubtractVectors(vTemp, right, vTemp);
        AddVectors(vTemp, fwd, vRectangle[1]);

        // Corner 3
        vTemp = end;
        vTemp[2] += ZnegOffset;
        AddVectors(vTemp, right, vTemp);
        SubtractVectors(vTemp, fwd, vRectangle[2]);

        // Corner 4
        vTemp = end;
        vTemp[2] += ZnegOffset;
        SubtractVectors(vTemp, right, vTemp);
        SubtractVectors(vTemp, fwd, vRectangle[3]);
    }

    // Run traces on all corners.
    for (new i = 0; i < 4; i++)
    {
        if (IsPointVisible(start, vRectangle[i]))
        {
            return true;
        }
    }

    return false;
}

/**
 * CS:S FarESP Blocking
 */
#define CS_TEAM_NONE		0	/**< No team yet. */
#define CS_TEAM_SPECTATOR	1	/**< Spectators. */
#define CS_TEAM_T			2	/**< Terrorists. */
#define CS_TEAM_CT			3	/**< Counter-Terrorists. */

#define MAX_RADAR_CLIENTS	36	// Max amount of client data we can include in one message.

new UserMsg:g_msgUpdateRadar = INVALID_MESSAGE_ID;
new bool:g_bPlayerSpotted[MAXPLAYERS+1];

new g_iSpottedCache[MAXPLAYERS+1];
new g_iUpdateFrequency;

new g_iPlayerManager = -1;
new g_iPlayerSpotted = -1;

new Handle:g_hCvarForceCamera = INVALID_HANDLE;
new bool:g_bForceCamera;

FarESP_Enable()
{
    if ((g_iPlayerManager = GetPlayerResourceEntity()) == -1)
        return;

    g_iPlayerSpotted = FindSendPropOffs("CCSPlayerResource", "m_bPlayerSpotted");
    SDKHook(g_iPlayerManager, SDKHook_ThinkPost, PlayerManager_ThinkPost);

    g_msgUpdateRadar = GetUserMessageId("UpdateRadar");
    HookUserMessage(g_msgUpdateRadar, Hook_UpdateRadar, true);

    HookEvent("player_death", FarESP_PlayerDeath, EventHookMode_Pre);

    g_hCvarForceCamera = FindConVar("mp_forcecamera");
    OnForceCameraChanged(g_hCvarForceCamera, "", "");
    HookConVarChange(g_hCvarForceCamera, OnForceCameraChanged);

    g_iUpdateFrequency = TIME_TO_TICK(2.0);

    g_bFarEspEnabled = true;
}

FarESP_Disable()
{
    SDKUnhook(g_iPlayerManager, SDKHook_ThinkPost, PlayerManager_ThinkPost);

    for (new i = 0; i < sizeof(g_bPlayerSpotted); i++)
    {
        g_bPlayerSpotted[i] = false;
    }

    UnhookUserMessage(g_msgUpdateRadar, Hook_UpdateRadar, true);

    UnhookEvent("player_death", FarESP_PlayerDeath, EventHookMode_Pre);

    UnhookConVarChange(g_hCvarForceCamera, OnForceCameraChanged);

    g_bFarEspEnabled = false;
}

public Action:FarESP_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IS_CLIENT(client) && IsClientInGame(client))
    {
        SendRadarClient(client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
    }

    return Plugin_Continue;
}

public OnForceCameraChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_bForceCamera = (GetConVarInt(convar) == 1);
}

public OnMapStart()
{
    if (g_bEnabled && !g_bFarEspEnabled && g_Game == Game_CSS)
    {
        FarESP_Enable();
    }
}

public OnMapEnd()
{
    if (g_bFarEspEnabled)
    {
        FarESP_Disable();
    }
}

public Action:Hook_UpdateRadar(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
    // We will send custom messages only.
    return Plugin_Handled;
}

public PlayerManager_ThinkPost(entity)
{
    if (!g_bFarEspEnabled)
        return;

    // Keep track of which players have been spotted.
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bProcess[i] && GetEntData(entity, g_iPlayerSpotted + i, 1))
        {
            // Immediately update this client's data.
            if (!g_bPlayerSpotted[i])
            {
                g_bPlayerSpotted[i] = true;
                SendRadarClient(i, USERMSG_BLOCKHOOKS);
            }

            g_iSpottedCache[i] = g_iTickCount + g_iUpdateFrequency;
        }
        else
        {
            g_bPlayerSpotted[i] = false;
        }
    }
}

FarESP_OnGameFrame()
{
    // Send the messages once per second and on different ticks.
    switch (g_iTickCount % g_iTickRate)
    {
        case 0:
        {
            SendRadarSpotted();
        }
        case 1:
        {
            SendRadarTeam(CS_TEAM_T);
        }
        case 2:
        {
            SendRadarTeam(CS_TEAM_CT);
        }
        case 3:
        {
            SendRadarObservers();
        }
        case 4:
        {
            SendRadarFakeTeam(CS_TEAM_T);
        }
        case 5:
        {
            SendRadarFakeTeam(CS_TEAM_CT);
        }
    }
}

SendRadarSpotted()
{
    // Send scrambled spotted data to all clients.
    decl iClients[MaxClients];
    new numClients, count;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bProcess[i])
        {
            iClients[numClients++] = i;
        }
    }

    if (!numClients)
        return;

    decl Float:vOrigin[3], Float:vAngles[3];
    new Handle:bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

    for (new i = 1; i <= MaxClients && count < MAX_RADAR_CLIENTS; i++)
    {
        if (g_bPlayerSpotted[i] && g_bProcess[i])
        {
            GetClientAbsOrigin(i, vOrigin);
            GetClientAbsAngles(i, vAngles);

            BfWriteByte(bf, i);
            BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] - MT_GetRandomFloat(500.0, 1000.0)) / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
            count++;
        }
    }

    BfWriteByte(bf, 0);
    EndMessage();
}

SendRadarTeam(team)
{
    // Send proper team data to all teammates.
    decl iClients[MaxClients];
    new numClients;

    for (new i = 1; i <= MaxClients; i++)
    {
        // Include dead players observering their teammates.
        if ((g_bProcess[i] || (g_bForceCamera && g_bIsObserver[i])) && g_iTeam[i] == team)
        {
            iClients[numClients++] = i;
        }
    }

    if (!numClients)
        return;

    decl Float:vOrigin[3], Float:vAngles[3], client;
    new Handle:bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

    // Limit payload early.
    if (numClients >= MAX_RADAR_CLIENTS)
        numClients = MAX_RADAR_CLIENTS - 1;

    for (new i = 0; i < numClients; i++)
    {
        client = iClients[i];

        GetClientAbsOrigin(client, vOrigin);
        GetClientAbsAngles(client, vAngles);

        BfWriteByte(bf, client);
        BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest(vOrigin[2] / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
    }

    BfWriteByte(bf, 0);
    EndMessage();
}

SendRadarFakeTeam(team)
{
    // Send fake data to team.
    decl iReceivers[MaxClients], iSenders[MaxClients];
    new numReceivers, numSenders, iReceiver;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bProcess[i])
        {
            if (g_iTeam[i] == team)
            {
                iReceivers[numReceivers++] = i;
            }
            else if (g_iSpottedCache[i] < g_iTickCount)
            {
                iSenders[numSenders++] = i;
            }
        }
    }

    if (!numReceivers || !numSenders)
        return;
	
    decl Float:vOrigin[3];
    new Handle:bf = StartMessageEx(g_msgUpdateRadar, iReceivers, numReceivers, USERMSG_BLOCKHOOKS);

    // Randomize so that every client is ensured fake data.
    SortIntegers(iReceivers, numReceivers, Sort_Random);

    // Randomize the payload before limiting.
    if (numSenders >= MAX_RADAR_CLIENTS)
    {
        SortIntegers(iSenders, numSenders, Sort_Random);
        numSenders = MAX_RADAR_CLIENTS - 1;
    }

    for (new i = 0; i < numSenders; i++)
    {
        GetClientAbsOrigin(iReceivers[iReceiver++], vOrigin);

        BfWriteByte(bf, iSenders[i]);
        BfWriteSBitLong(bf, RoundToNearest((vOrigin[0] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest((vOrigin[1] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
        BfWriteSBitLong(bf, RoundToNearest(MT_GetRandomFloat(-180.0, 180.0)), 9);

        if (iReceiver >= numReceivers)
            iReceiver = 0;
    }
 
    BfWriteByte(bf, 0);
    EndMessage();
}

SendRadarClient(client, flags)
{
    // A player was spotted and needs to be sent out to all clients.
    decl iClients[MaxClients];
    new numClients, iTeam = g_iTeam[client];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bProcess[i] && g_iTeam[i] != iTeam)
        {
            iClients[numClients++] = i;
        }
    }
    
    if (!numClients)
        return;

    decl Float:vOrigin[3], Float:vAngles[3];
    new Handle:bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, flags);

    GetClientAbsOrigin(client, vOrigin);
    GetClientAbsAngles(client, vAngles);

    BfWriteByte(bf, client);
    BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
    BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
    BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] - MT_GetRandomFloat(500.0, 1000.0)) / 4.0), 13);
    BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);

    BfWriteByte(bf, 0);
    EndMessage();
}

SendRadarObservers()
{
    // Send all player data to all observers.
    decl iClients[MaxClients];
    new numClients, count;

    for (new i = 1; i <= MaxClients; i++)
    {
        // Include teammate-observers if forcecamera is disabled.
        if (g_bIsObserver[i] && (!g_bForceCamera || g_iTeam[i] <= CS_TEAM_SPECTATOR))
        {
            iClients[numClients++] = i;
        }
    }

    if (!numClients)
        return;

    decl Float:vOrigin[3], Float:vAngles[3];
    new Handle:bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

    for (new i = 1; i <= MaxClients && count < MAX_RADAR_CLIENTS; i++)
    {
        if (g_bProcess[i])
        {
            GetClientAbsOrigin(i, vOrigin);
            GetClientAbsAngles(i, vAngles);

            BfWriteByte(bf, i);
            BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest(vOrigin[2] / 4.0), 13);
            BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
            count++;
        }
    }

    BfWriteByte(bf, 0);
    EndMessage();
}