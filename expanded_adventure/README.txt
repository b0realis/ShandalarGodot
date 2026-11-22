Expanded adventure plugins
==========================

This folder holds adventure plugins: small packages of new lands for the
Shandalar adventure, reached by ship from a mainland harbor, and of new
places (sites plugins) that stand on the mainland and on those lands. A
plugin is a .zip file (or an unpacked folder) with a plugin.json at its top.

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
ship home at the port; a missing sites plugin's places are hidden until it
is back. Put the plugin back to go on.

THE PROTOTYPE
Fallen_Empires_Refuge_prototype.zip, "The Last Refuge", is a game-design
and learning demo: original fiction, not official Magic canon and not new
official content. It needs card pack 2, Fallen Empires. Play it, then read
it: every file is explained in the guide.

THE PLACES
Old_Adventurers_Hut.zip, "An Old Adventurer's Hut": a hut in the mainland's
woods. For 1000 gold the old man inside tells you where a dungeon lies that
nobody else knows of. Conjuration_Wizard_Guild.zip, "Conjuration Wizard
Guild": a wizards' tower on the mainland and on every island, whose
conjurers copy a card you carry for 2000 gold, then 4000, 8000 and 12000,
and then never again. Neither needs a card pack. Each is a finished place,
and a study for the places players wish for.

THE STUDY PLACES
Four small places, each made with a few of the authoring tool's commands
(its README.txt holds them) to show one thing a place can do. In
Gamblers_Den.zip, "The Gambler's Den", Odo Three-Fingers throws bone dice
for 50 gold a throw. Riddle_Stone.zip, "The Riddle Stone", asks one riddle
and pays 100 gold for the right answer. In Wandering_Collector.zip, "The
Wandering Collector", a collector pays 150 gold for each Ornithopter you
hand over. In Duelists_Ring.zip, "The Duelist's Ring", Marda Ironhand duels
for a wager of 50 gold. None needs a card pack. Each is switched on or off
by itself at the Embark, like every plugin; unticked, it changes nothing.

MAKING YOUR OWN
GUIDE/index.html is the authors' guide: how a plugin is made, tested and
packed, with the full reference of every file; GUIDE/sites.html tells how a
sites plugin's places are made. Open it in any web browser;
it needs no internet. The tool it uses is tools/adventure_plugin.py in the
game folder.
