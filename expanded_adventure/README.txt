Expanded adventure plugins
==========================

This folder holds adventure plugins: small packages of new lands for the
Shandalar adventure, reached by ship from a mainland harbor. A plugin is a
.zip file (or an unpacked folder) with a plugin.json at its top.

INSTALLING A PLUGIN
Put the plugin's .zip in your plugins folder: the folder Options shows on
its "Adventure plugins folder" line (the expanded_adventure_folder key in
settings.cfg moves it). A plugin in this folder beside the game is found
too. Then start a new adventure, press "Expanded adventure plugins..." at
the bottom of the card-pack list and tick it. A plugin names the card packs
it needs; ticking the plugin ticks those packs.

A plugin is data only: text, pictures, music and JSON. The game reads its
files and never runs anything from one. A plugin with a problem is listed
greyed, with the reason.

If a plugin goes missing in the middle of an adventure, the save still
opens. The plugin's progress is kept, and a hero on its island finds a
ship home at the port. Put the plugin back to go on.

THE PROTOTYPE
Fallen_Empires_Refuge_prototype.zip, "The Last Refuge", is a game-design
and learning demo: original fiction, not official Magic canon and not new
official content. It needs card pack 2, Fallen Empires. Play it, then read
it: every file is explained in the guide.

MAKING YOUR OWN
GUIDE/index.html is the authors' guide: how a plugin is made, tested and
packed, with the full reference of every file. Open it in any web browser;
it needs no internet. The tool it uses is tools/adventure_plugin.py in the
game folder.
