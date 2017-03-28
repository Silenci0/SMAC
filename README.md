# SMAC
Sourcemod Anti-Cheat

For a lot of people, SMAC has been one of those more elusive plugins due to some of the issues surrounding it involving copyrights and headers. In 0.8.6.0, the original authors added the headers to it and left it at that. During that time, I was working on my own fork of it specifically for ZPS. So not only does the code have all the appropriate headers, but included is a license with those headers as well, so it should be okay to distribute, post, branch, and fork once again as needed provided everyone adheres to the license.

Because of how complex SMAC is, I am also including the wiki from the wayback machine. You can find it here: http://web.archive.org/web/20150521190758/http://smac.sx/wiki/doku.php

I may do something about this later and add an actual webpage someplace so it can be updated. But below are some of the changes I made to SMAC for ZPS specifically.


0.8.6.1 Initial Commit (9-1-2016)
-----------------
- Used latest 0.8.6.0 code as base (this included all GPL headers and such for SMAC team and CodingDirect LLC).
- Added ZPS support. Support for other games should remain the same as the 0.8.6.0 branch (so if it doesn't work for that particular branch, chances are it will not work for this version as it was updated for ZPS only)
- Removed updater code/references. Updater will no longer be used by this fork of SMAC.
- Re-tabbed all code. 1 Tab = 4 whitespaces.
- Included all relevant extensions, translations, script files, and pre-compiled plugins
- Most of this version's modules were tested for ZPS except game specific ones. smac_cvars works, but if you use any fake clients/bots that were custom made for ZPS (or any game for that matter), it doesn't mesh too well due to how they look like at them as players (causing tons of lag issues fyi).