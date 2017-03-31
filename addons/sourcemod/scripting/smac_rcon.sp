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
#include <smac>
#undef REQUIRE_EXTENSIONS
#tryinclude <smrcon>

/* Plugin Info */
public Plugin:myinfo =
{
    name = "SMAC Rcon Locker",
    author = SMAC_AUTHOR,
    description = "Protects against rcon crashes and exploits",
    version = SMAC_VERSION,
    url = SMAC_URL
};

/* Globals */
new Handle:g_hCvarRconPass = INVALID_HANDLE;
new String:g_sRconRealPass[128];
new bool:g_bRconLocked = false;

new Handle:g_hWhitelist = INVALID_HANDLE;
new bool:g_bSMrconLoaded = false;

/* Plugin Functions */
public OnPluginStart()
{
    // Convars.
    g_hCvarRconPass = FindConVar("rcon_password");
    HookConVarChange(g_hCvarRconPass, OnRconPassChanged);
    
    // SM RCon.
    g_hWhitelist = CreateTrie();
    g_bSMrconLoaded = LibraryExists("smrcon");
    
    RegAdminCmd("smac_rcon_addip", Command_AddIP, ADMFLAG_ROOT, "Adds an IP address to the rcon whitelist.");
    RegAdminCmd("smac_rcon_removeip", Command_RemoveIP, ADMFLAG_ROOT, "Removes an IP address from the rcon whitelist.");
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "smrcon"))
    {
        g_bSMrconLoaded = true;
    }
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "smrcon"))
    {
        ClearTrie(g_hWhitelist);
        g_bSMrconLoaded = false;
    }
}

public OnConfigsExecuted()
{
    if (!g_bRconLocked)
    {
        GetConVarString(g_hCvarRconPass, g_sRconRealPass, sizeof(g_sRconRealPass));
        g_bRconLocked = true;
    }
}

public OnRconPassChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (g_bRconLocked && !StrEqual(newValue, g_sRconRealPass))
    {
        SMAC_Log("Rcon password changed to \"%s\". Reverting back to original config value.", newValue);
        SetConVarString(g_hCvarRconPass, g_sRconRealPass);
    }
}

public Action:Command_AddIP(client, args)
{
    if (!g_bSMrconLoaded)
    {
        ReplyToCommand(client, "This feature requires the SM RCon extension to be loaded.");
        return Plugin_Handled;
    }
    
    if (args != 1)
    {
        ReplyToCommand(client, "Usage: smac_rcon_addip <ip>");
        return Plugin_Handled;
    }

    decl String:sIP[32];
    GetCmdArg(1, sIP, sizeof(sIP));

    if (SetTrieValue(g_hWhitelist, sIP, 1, false))
    {
        if (GetTrieSize(g_hWhitelist) == 1)
            ReplyToCommand(client, "Rcon whitelist enabled.");
        
        ReplyToCommand(client, "You have successfully added %s to the rcon whitelist.", sIP);
    }
    else
    {
        ReplyToCommand(client, "%s already exists in the rcon whitelist.", sIP);
    }
    
    return Plugin_Handled;
}

public Action:Command_RemoveIP(client, args)
{
    if (!g_bSMrconLoaded)
    {
        ReplyToCommand(client, "This feature requires the SM RCon extension to be loaded.");
        return Plugin_Handled;
    }
    
    if (args != 1)
    {
        ReplyToCommand(client, "Usage: smac_rcon_removeip <ip>");
        return Plugin_Handled;
    }

    decl String:sIP[32];
    GetCmdArg(1, sIP, sizeof(sIP));

    if (RemoveFromTrie(g_hWhitelist, sIP))
    {
        ReplyToCommand(client, "You have successfully removed %s from the rcon whitelist.", sIP);
        
        if (!GetTrieSize(g_hWhitelist))
            ReplyToCommand(client, "Rcon whitelist disabled.");
    }
    else
    {
        ReplyToCommand(client, "%s is not in the rcon whitelist.", sIP);
    }
    
    return Plugin_Handled;
}

public Action:SMRCon_OnAuth(rconId, const String:address[], const String:password[], &bool:allow)
{
    // Check against whitelist before continuing.
    decl dummy;
    
    if (!GetTrieSize(g_hWhitelist) || GetTrieValue(g_hWhitelist, address, dummy))
        return Plugin_Continue;
    
    allow = false;
    return Plugin_Changed;
}

public Action:SMRCon_OnCommand(rconId, const String:address[], const String:command[], &bool:allow)
{
    // Check against whitelist before continuing.
    decl dummy;
    
    if (!GetTrieSize(g_hWhitelist) || GetTrieValue(g_hWhitelist, address, dummy))
        return Plugin_Continue;
    
    allow = false;
    return Plugin_Changed;
}
