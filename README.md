# SMAC
Sourcemod Anti-Cheat

0.8.6.1 Initial Commit (9-1-2016)
-----------------
- Used latest 0.8.6.0 code as base (this included all GPL headers and such for SMAC team and CodingDirect LLC).
- Added ZPS support. Support for other games should remain the same as the 0.8.6.0 branch (so if it doesn't work for that, it will not work for this version)
- Removed updater code/references. Updater will no longer be used by this fork of SMAC.
- Re-tabbed all code. 1 Tab = 4 whitespaces.
- Included all relevant extensions, translations, script files, and pre-compiled plugins
- Most of this version's modules were tested for ZPS except game specific ones. smac_cvars works, but if you use any fake clients/bots that were custom made, it doesn't mesh too well. Native bots might work better, but keep in mind that it will need to look at them as players.
- Because the code is freely available and the licensing is all there, go ahead and create branch after branch of it. Do whatever you want, just adhere to the license and keep the headers for the SMAC Team and CodingDirect LLC. I do not need (or want) credit.