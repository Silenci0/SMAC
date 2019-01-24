# SMAC
Sourcemod Anti-Cheat

For a lot of people, SMAC has been one of those more elusive plugins due to some of the issues surrounding it involving copyrights and headers. In 0.8.6.0, the original authors added the headers to it and left it at that. During that time, I was working on my own fork of it specifically for ZPS. So not only does the code have all the appropriate headers, but included is a license with those headers as well, so it should be okay to distribute, post, branch, and fork once again as needed provided everyone adheres to the license.

Although progress is a bit slow, I do hope to add more features and update detections for various aimbots/hacks over the next few iterations. My hope is to return SMAC to active development as a free, open source project for multiple source-based games. Not sure how well that will go, but I'll give it a shot.

For information about the plugin and its modules, please use the wiki here: https://github.com/Silenci0/SMAC/wiki

# Changelog
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