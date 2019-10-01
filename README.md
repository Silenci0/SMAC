# SMAC
Sourcemod Anti-Cheat

For a lot of people, SMAC has been one of those more elusive plugins due to some of the issues surrounding it involving copyrights and headers. In 0.8.6.0, the original authors added the headers to it and left it at that. During that time, I was working on my own fork of it specifically for ZPS which evolved from there into the current fork that is seen today. So not only does the code have all the appropriate headers, but included is a license with those headers as well, so it should be okay to distribute, post, branch, and fork once again as needed provided everyone adheres to the license.

Although progress is a bit slow, I do hope to add more features and update detections for various aimbots/hacks over the next few iterations. My hope is to return SMAC to active development as a free, open source project for multiple source-based games. Not sure how well that will go, but I'll give it a shot. 

Also, if you want to help contribute to the plugin, please feel free to issue pull requests if you have changes/updates that you think would be good. Keep in mind that the code will be reviewed to determine if it will be accepted or not. 

For information about the plugin and its modules, please use the wiki here: https://github.com/Silenci0/SMAC/wiki

# Changelog
0.8.6.6 Update (09-30-2019)
-----------------
- Updated support for Sourcebans++ to use latest natives instead of the depreciated native.
    * SMAC will attempt to use the sourcebans++ native first, then the depreciated native next. This is for backwards compatibility.
    * This was brought up by Drmohammad11 in this issue here: https://github.com/Silenci0/SMAC/issues/13
- Added Chinese translation to SMAC via pull request from LemonPAKA: https://github.com/Silenci0/SMAC/pull/10
- Depreciated support for the EAC module. The code will still be available, but the plugin will no longer be compiled. With changes to the Easy Anti-Cheat website, it is no longer possible (as far as I am aware) to use this module or modify it to work as it once did. It will be unable to grab the information needed to check if a player was banned by Easy Anti-Cheat. Sorry!
- Known Issue: The ESEA module currently does not work very well due to the ESEA website/Cloudflare denying the request. This is still being worked on: https://github.com/Silenci0/SMAC/issues/11
- Known Issue: Bhop detection from the autotrigger module is not catching some people using scripts. Issue is being worked on and was discussed here: https://forums.alliedmods.net/showthread.php?t=318420
 

0.8.6.5 Update (07-26-2019)
-----------------
- Updated the smac_commands.smx module:
    * Added the command snd_setsoundparam to the CS:GO ignore commands list in the code. While this command was removed from CS:GO on 05/29/2019, it seems that it has been getting randomly spammed and causing users to be kicked. This issue was brought up in https://github.com/Silenci0/SMAC/issues/8
    * Please note that you can add commands to block or ignore via plugin commands from smac_commands.smx independently. Please see this wiki page for details: https://github.com/Silenci0/SMAC/wiki/Command-Monitor
    * Added new convar smac_anticmdspam_kick. This toggles the ability to kick users for command spam (which is set as the default response) or to simply notify when someone is spamming.
- Updated smac.cfg with new cvars and recompiled all smac plugins to reflect updated version.

0.8.6.4 Update (05-07-2019)
-----------------
- Fixed a couple of issues related to tickcount with the smac_eyetest module that was causing false positives to occur in TF2 and CS:GO (someone might want to confirm for CS:GO):
    * Alt-tabbing no longer causes users to trigger the tickcount cheat detection each time it occurs. This was reported in the SMAC thread: https://forums.alliedmods.net/showthread.php?t=307188
    * A rare issue (caused by the same tickcount detections) in TF2 when a player would be running a taunt (such as conga) and attempting to open the contracts menu. More info here: https://github.com/Silenci0/SMAC/issues/1
    * Please be sure to leave compatibility mode on and set bans to off. While this issue is possibly resolved, that does not mean it might not break in the future.
- Fixed a minor issue with the smac_speedhack module not checking for the player being in-game (https://github.com/Silenci0/SMAC/issues/7)

Be sure to test these and if you have any feedback or comments, feel free to post in the SMAC forums (https://forums.alliedmods.net/forumdisplay.php?f=133) or create an issue on github. Thanks!

0.8.6.3 Update (01-23-2019)
-----------------
- Re-added achievement-related checks back to smac_client. Originally, this was removed some time ago due to an issue with ZPS 2.4, but has been re-added as ZPS 3.0+ has achievements.
- Updated tf2 weapon classes to ignore in smac_aimbot. Most of the weapon classes added had weapons that did not necessarily benefit from aimbot. The weapons classes ignored are as follows:
    * tf_weapon_slap - ex: Hot Hand
    * tf_weapon_buff_item - ex: The Buff Banner
    * tf_weapon_parachute - ex: The B.A.S.E. Jumper
    * tf_weapon_breakable_sign - ex: Neon Annihilator 
    * tf_wearable_demoshield - ex: Splendid Screen
    * tf_wearable_razorback - ex: The Razorback
    * tf_wearable - ex: Mantreads
    * tf_weapon_rocketpack - ex: Thermal Thruster 
    * tf_weapon_lunchbox_drink - ex: Bonk! Bonk! Atomic Punch
    * tf_weapon_lunchbox - ex: Sandvich
    * saxxy - ex: Saxxy, Prinny Machete
- Updated zps weapon classes to ignore in smac_aimbot. They are as follows:
    * weapon_baguette
    * weapon_pipewrench
    * weapon_wrench
    * weapon_meatcleaver
- Fixed a warning/bug in smac_cvar regarding variable shadowing for the CvarComp:CCompType variable in some parts of the code. I have renamed affected variables to SCCompType to avoid possible conflicts.
- All plugins have been compiled for SM 1.9

0.8.6.2 Update (12-09-2018)
-----------------
- Only updated the change log with wiki information. No plugins or scripts were updated yet.

0.8.6.2 Update (6-11-2018)
-----------------
- Compiled/Updated codebase for SM 1.8
- Updated SMAC stocks and wallhack code to use FindDataMapInfo and FindSendPropInfo instead of FindDataMapOffs and FindSendPropOffs.
- Updated smac_rcon module to have logging for attempts to use rcon_password on the server from a non-whitelisted IP. This functionality REQUIRES the SM Rcon extension found here: https://forums.alliedmods.net/showthread.php?t=168403. Please note that some games might not work with this extension!

0.8.6.1 Initial Commit (9-1-2016)
-----------------
- Used latest 0.8.6.0 code as base (this included all GPL headers and such for SMAC team and CodingDirect LLC).
- Added ZPS support. Support for other games should remain the same as the 0.8.6.0 branch (so if it doesn't work for that particular branch, chances are it will not work for this version as it was updated for ZPS only)
- Removed updater code/references. Updater will no longer be used by this fork of SMAC.
- Re-tabbed all code. 1 Tab = 4 whitespaces.
- Included all relevant extensions, translations, script files, and pre-compiled plugins
- Most of this version's modules were tested for ZPS except game specific ones. smac_cvars works, but if you use any fake clients/bots that were custom made for ZPS (or any game for that matter), it doesn't mesh too well due to how they look like at them as players (causing tons of lag issues fyi).