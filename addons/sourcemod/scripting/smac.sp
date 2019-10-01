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
#include <colors>

/* Plugin Info */
public Plugin:myinfo =
{
    name = "SourceMod Anti-Cheat",
    author = SMAC_AUTHOR,
    description = "Open source anti-cheat plugin for SourceMod",
    version = SMAC_VERSION,
    url = SMAC_URL
};

/* Globals */
#define SOURCEBANS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SBBanPlayer") == FeatureStatus_Available) // Depreciated in SB++, leaving in for legacy/compatibility!
#define SBPP_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
#define SOURCEIRC_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "IRC_MsgFlaggedChannels") == FeatureStatus_Available)
#define IRCRELAY_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "IRC_Broadcast") == FeatureStatus_Available)

enum IrcChannel
{
    IrcChannel_Public  = 1,
    IrcChannel_Private = 2,
    IrcChannel_Both    = 3
}

native SBBanPlayer(client, target, time, String:reason[]); // Depreciated in SB++, leaving in for legacy/compatibility!
native SBPP_BanPlayer(client, target, time, String:reason[]);
native IRC_MsgFlaggedChannels(const String:flag[], const String:format[], any:...);
native IRC_Broadcast(IrcChannel:type, const String:format[], any:...);

new GameType:g_Game = Game_Unknown;
new Handle:g_hCvarVersion = INVALID_HANDLE;
new Handle:g_hCvarWelcomeMsg = INVALID_HANDLE;
new Handle:g_hCvarBanDuration = INVALID_HANDLE;
new Handle:g_hCvarLogVerbose = INVALID_HANDLE;
new Handle:g_hCvarIrcMode = INVALID_HANDLE;
new String:g_sLogPath[PLATFORM_MAX_PATH];

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    // Detect game.
    decl String:sGame[64];
    GetGameFolderName(sGame, sizeof(sGame));

    if (StrEqual(sGame, "cstrike") || StrEqual(sGame, "cstrike_beta"))
        g_Game = Game_CSS;
    else if (StrEqual(sGame, "tf") || StrEqual(sGame, "tf_beta"))
        g_Game = Game_TF2;
    else if (StrEqual(sGame, "dod"))
        g_Game = Game_DODS;
    else if (StrEqual(sGame, "insurgency"))
        g_Game = Game_INSMOD;
    else if (StrEqual(sGame, "left4dead"))
        g_Game = Game_L4D;
    else if (StrEqual(sGame, "left4dead2"))
        g_Game = Game_L4D2;
    else if (StrEqual(sGame, "hl2mp"))
        g_Game = Game_HL2DM;
    else if (StrEqual(sGame, "fistful_of_frags"))
        g_Game = Game_FOF;
    else if (StrEqual(sGame, "garrysmod"))
        g_Game = Game_GMOD;
    else if (StrEqual(sGame, "hl2ctf"))
        g_Game = Game_HL2CTF;
    else if (StrEqual(sGame, "hidden"))
        g_Game = Game_HIDDEN;
    else if (StrEqual(sGame, "nucleardawn"))
        g_Game = Game_ND;
    else if (StrEqual(sGame, "csgo"))
        g_Game = Game_CSGO;
    else if (StrEqual(sGame, "zps"))
        g_Game = Game_ZPS;
    
    // Path used for logging.
    BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/SMAC.log");
    
    // Optional dependencies.
    MarkNativeAsOptional("SBBanPlayer");
    MarkNativeAsOptional("SBPP_BanPlayer");
    MarkNativeAsOptional("IRC_MsgFlaggedChannels");
    MarkNativeAsOptional("IRC_Broadcast");
    
    API_Init();
    RegPluginLibrary("smac");
    
    return APLRes_Success;
}

public OnPluginStart()
{
    LoadTranslations("smac.phrases");

    // Convars.
    g_hCvarVersion = CreateConVar("smac_version", SMAC_VERSION, "SourceMod Anti-Cheat", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    OnVersionChanged(g_hCvarVersion, "", "");
    HookConVarChange(g_hCvarVersion, OnVersionChanged);
    
    g_hCvarWelcomeMsg = CreateConVar("smac_welcomemsg", "0", "Display a message saying that your server is protected.", 0, true, 0.0, true, 1.0);
    g_hCvarBanDuration = CreateConVar("smac_ban_duration", "0", "The duration in minutes used for automatic bans. (0 = Permanent)", 0, true, 0.0);
    g_hCvarLogVerbose = CreateConVar("smac_log_verbose", "0", "Include extra information about a client being logged.", 0, true, 0.0, true, 1.0);
    g_hCvarIrcMode = CreateConVar("smac_irc_mode", "1", "Which messages should be sent to IRC plugins. (1 = Admin notices, 2 = Mimic log)", 0, true, 1.0, true, 2.0);
    
    // Commands.
    RegAdminCmd("smac_status", Command_Status, ADMFLAG_GENERIC, "View the server's player status.");
}

public OnAllPluginsLoaded()
{
    // Don't clutter the config if they aren't using IRC anyway.
    if (!SOURCEIRC_AVAILABLE() && !IRCRELAY_AVAILABLE())
    {
        SetConVarFlags(g_hCvarIrcMode, GetConVarFlags(g_hCvarIrcMode) | FCVAR_DONTRECORD);
    }
    
    // Wait for other modules to create their convars.
    AutoExecConfig(true, "smac");
    
    PrintToServer("SourceMod Anti-Cheat %s has been successfully loaded.", SMAC_VERSION);
}

public OnVersionChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (!StrEqual(newValue, SMAC_VERSION))
    {
        SetConVarString(g_hCvarVersion, SMAC_VERSION);
    }
}

public OnClientPutInServer(client)
{
    if (GetConVarBool(g_hCvarWelcomeMsg))
    {
        CreateTimer(10.0, Timer_WelcomeMsg, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:Timer_WelcomeMsg(Handle:timer, any:serial)
{
    new client = GetClientFromSerial(serial);
    
    if (IS_CLIENT(client) && IsClientInGame(client))
    {
        CPrintToChat(client, "%t%t", "SMAC_Tag", "SMAC_WelcomeMsg");
    }
        
    return Plugin_Stop;
}

public Action:Command_Status(client, args)
{
    PrintToConsole(client, "%s  %-40s %s", "UserID", "AuthID", "Name");

    decl String:sAuthID[MAX_AUTHID_LENGTH];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientConnected(i))
            continue;
        
        if (!GetClientAuthId(i, AuthId_Steam2, sAuthID, sizeof(sAuthID), true))
        {
            if (GetClientAuthId(i, AuthId_Steam2, sAuthID, sizeof(sAuthID), false))
            {
                Format(sAuthID, sizeof(sAuthID), "%s (Not Validated)", sAuthID);
            }
            else
            {
                strcopy(sAuthID, sizeof(sAuthID), "Unknown");
            }
        }
        
        PrintToConsole(client, "%6d  %-40s %N", GetClientUserId(i), sAuthID, i);
    }

    return Plugin_Handled;
}

SMAC_RelayToIRC(const String:format[], any:...)
{
    decl String:sBuffer[256];
    SetGlobalTransTarget(LANG_SERVER);
    VFormat(sBuffer, sizeof(sBuffer), format, 2);
    
    if (SOURCEIRC_AVAILABLE())
    {
        IRC_MsgFlaggedChannels("ticket", sBuffer);
    }
    if (IRCRELAY_AVAILABLE())
    {
        IRC_Broadcast(IrcChannel_Private, sBuffer);
    }
}

/* API - Natives & Forwards */

new Handle:g_OnCheatDetected = INVALID_HANDLE;

API_Init()
{
    CreateNative("SMAC_GetGameType", Native_GetGameType);
    CreateNative("SMAC_Log", Native_Log);
    CreateNative("SMAC_LogAction", Native_LogAction);
    CreateNative("SMAC_Ban", Native_Ban);
    CreateNative("SMAC_PrintAdminNotice", Native_PrintAdminNotice);
    CreateNative("SMAC_CreateConVar", Native_CreateConVar);
    CreateNative("SMAC_CheatDetected", Native_CheatDetected);
    
    g_OnCheatDetected = CreateGlobalForward("SMAC_OnCheatDetected", ET_Event, Param_Cell, Param_String, Param_Cell, Param_Cell);
}

// native GameType:SMAC_GetGameType();
public Native_GetGameType(Handle:plugin, numParams)
{
    return _:g_Game;
}

// native SMAC_Log(const String:format[], any:...);
public Native_Log(Handle:plugin, numParams)
{
    decl String:sFilename[64], String:sBuffer[256];
    GetPluginBasename(plugin, sFilename, sizeof(sFilename));
    FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
    LogToFileEx(g_sLogPath, "[%s] %s", sFilename, sBuffer);
    
    // Relay log to IRC.
    if (GetConVarInt(g_hCvarIrcMode) == 2)
    {
        SMAC_RelayToIRC("[%s] %s", sFilename, sBuffer);
    }
}

// native SMAC_LogAction(client, const String:format[], any:...);
public Native_LogAction(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    
    if (!IS_CLIENT(client) || !IsClientConnected(client))
    {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
    }
    
    decl String:sAuthID[MAX_AUTHID_LENGTH];
    if (!GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), true))
    {
        if (GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), false))
        {
            Format(sAuthID, sizeof(sAuthID), "%s (Not Validated)", sAuthID);
        }
        else
        {
            strcopy(sAuthID, sizeof(sAuthID), "Unknown");
        }
    }
    
    decl String:sIP[17];
    if (!GetClientIP(client, sIP, sizeof(sIP)))
    {
        strcopy(sIP, sizeof(sIP), "Unknown");
    }
    
    decl String:sVersion[16], String:sFilename[64], String:sBuffer[512];
    GetPluginInfo(plugin, PlInfo_Version, sVersion, sizeof(sVersion));
    GetPluginBasename(plugin, sFilename, sizeof(sFilename));
    FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);
    
    // Verbose client logging.
    if (GetConVarBool(g_hCvarLogVerbose) && IsClientInGame(client))
    {
        decl String:sMap[MAX_MAPNAME_LENGTH], Float:vOrigin[3], Float:vAngles[3], String:sWeapon[32], iTeam, iLatency;
        GetCurrentMap(sMap, sizeof(sMap));
        GetClientAbsOrigin(client, vOrigin);
        GetClientEyeAngles(client, vAngles);
        GetClientWeapon(client, sWeapon, sizeof(sWeapon));
        iTeam = GetClientTeam(client);
        iLatency = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) * 1000.0);
        
        LogToFileEx(g_sLogPath,
            "[%s | %s] %N (ID: %s | IP: %s) %s\n\tMap: %s | Origin: %.0f %.0f %.0f | Angles: %.0f %.0f %.0f | Weapon: %s | Team: %i | Latency: %ims",
            sFilename,
            sVersion,
            client,
            sAuthID,
            sIP,
            sBuffer,
            sMap,
            vOrigin[0], vOrigin[1], vOrigin[2],
            vAngles[0], vAngles[1], vAngles[2],
            sWeapon,
            iTeam,
            iLatency);
    }
    else
    {
        LogToFileEx(g_sLogPath, "[%s | %s] %N (ID: %s | IP: %s) %s", sFilename, sVersion, client, sAuthID, sIP, sBuffer);
    }
    
    // Relay minimal log to IRC.
    if (GetConVarInt(g_hCvarIrcMode) == 2)
    {
        SMAC_RelayToIRC("[%s | %s] %N (ID: %s | IP: %s) %s", sFilename, sVersion, client, sAuthID, sIP, sBuffer);
    }
}

// native SMAC_Ban(client, const String:reason[], any:...);
public Native_Ban(Handle:plugin, numParams)
{
    decl String:sVersion[16], String:sReason[256];
    new client = GetNativeCell(1);
    new duration = GetConVarInt(g_hCvarBanDuration);
    
    GetPluginInfo(plugin, PlInfo_Version, sVersion, sizeof(sVersion));
    FormatNativeString(0, 2, 3, sizeof(sReason), _, sReason);
    Format(sReason, sizeof(sReason), "SMAC %s: %s", sVersion, sReason);
    
    if (SBPP_AVAILABLE())
    {
        SBPP_BanPlayer(0, client, duration, sReason);
    }
    else if (SOURCEBANS_AVAILABLE())
    {
        SBBanPlayer(0, client, duration, sReason);
    }
    else
    {
        decl String:sKickMsg[256];
        FormatEx(sKickMsg, sizeof(sKickMsg), "%T", "SMAC_Banned", client);
        BanClient(client, duration, BANFLAG_AUTO, sReason, sKickMsg, "SMAC");
    }
    
    // NOTE: There is an error that is caused by kicking a client that doesn't exist
    // All that is needed is a simple check to see if the client is in game.
    // If they are, kick, if not, skip this and save our error logs!
    if(IsClientConnected(client))
    {
        KickClient(client, sReason);
    }
}

// native SMAC_PrintAdminNotice(const String:format[], any:...);
public Native_PrintAdminNotice(Handle:plugin, numParams)
{
    decl String:sBuffer[192];

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "smac_admin_notices", ADMFLAG_GENERIC, true))
        {
            SetGlobalTransTarget(i);
            FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
            CPrintToChat(i, "%t%s", "SMAC_Tag", sBuffer);
        }
    }
    
    // Relay admin notice to IRC.
    if (GetConVarInt(g_hCvarIrcMode) == 1)
    {
        SetGlobalTransTarget(LANG_SERVER);
        FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
        Format(sBuffer, sizeof(sBuffer), "%t%s", "SMAC_Tag", sBuffer);
        CRemoveTags(sBuffer, sizeof(sBuffer));
        SMAC_RelayToIRC(sBuffer);
    }
}

// native Handle:SMAC_CreateConVar(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0);
public Native_CreateConVar(Handle:plugin, numParams)
{
    decl String:name[64], String:defaultValue[16], String:description[192];
    GetNativeString(1, name, sizeof(name));
    GetNativeString(2, defaultValue, sizeof(defaultValue));
    GetNativeString(3, description, sizeof(description));
    
    new flags = GetNativeCell(4);
    new bool:hasMin = bool:GetNativeCell(5);
    new Float:min = Float:GetNativeCell(6);
    new bool:hasMax = bool:GetNativeCell(7);
    new Float:max = Float:GetNativeCell(8);
    
    decl String:sFilename[64];
    GetPluginBasename(plugin, sFilename, sizeof(sFilename));
    Format(description, sizeof(description), "[%s] %s", sFilename, description);
    
    return _:CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}

// native Action:SMAC_CheatDetected(client, DetectionType:type = Detection_Unknown, Handle:info = INVALID_HANDLE);
public Native_CheatDetected(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    
    if (!IS_CLIENT(client) || !IsClientConnected(client))
    {
        ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
    }
    
    // Block duplicate detections.
    if (IsClientInKickQueue(client))
    {
        return _:Plugin_Handled;
    }
    
    decl String:sFilename[64];
    GetPluginBasename(plugin, sFilename, sizeof(sFilename));
    
    new DetectionType:type = Detection_Unknown;
    new Handle:info = INVALID_HANDLE;
    
    if (numParams == 3)
    {
        // caller is using newer cheat detected native
        type = DetectionType:GetNativeCell(2);
        info = Handle:GetNativeCell(3);
    }
    
    // forward Action:SMAC_OnCheatDetected(client, const String:module[], DetectionType:type, Handle:info);
    new Action:result = Plugin_Continue;
    Call_StartForward(g_OnCheatDetected);
    Call_PushCell(client);
    Call_PushString(sFilename);
    Call_PushCell(type);
    Call_PushCell(info);
    Call_Finish(result);
    
    return _:result;
}
