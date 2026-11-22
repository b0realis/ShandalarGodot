The Gambler's Den
=================

A sites plugin for Shandalar (plugin API 3): a new place on the mainland.

THE PLACE
A striped tent stands a little way off the road, its lamp lit at any hour.
Inside sits Odo Three-Fingers, who lost the other two, he says, to a djinn
who cheated better than he did. He throws three bone dice for fifty gold:
nothing, seventy-five, or a hundred and fifty. Five throws, and he packs the
cup away. Those who have thrown three times are shown the high table in the
back, where the stakes are two hundred and the prize may be an amulet.

WHAT YOU NEED
Nothing but the game: the plugin needs no card pack. At the Embark, open
"Expanded adventure plugins..." and tick it.

A STUDY
The den is a finished place, and a study of the roll: an effect that picks
one of several outcomes by weight. The odds are written in sites.json for
anyone to read, and a walk prints them with the gold a throw pays on
average, so an author sees at once whether the house wins. It also shows a
counter ({count}), a pane opened by a talk button, and a button that appears
only when a counter has grown.

HOW IT WAS MADE
Every line of its JSON was written by the game's authoring tool; nobody
edited a file by hand. These are the commands, in order, run from the
game's folder, one command a line (each says what it did and what comes
next):

    python3 tools/adventure_plugin.py new Gamblers_Den --id gamblers_den --name "The Gambler's Den" --author "Shandalar Godot" --kind sites
    python3 tools/adventure_plugin.py add-place Gamblers_Den --id den --name "The Gambler's Den" --recipe gambler
    python3 tools/adventure_plugin.py remove-place Gamblers_Den --id shrine
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.intro "A striped tent, its lamp lit though the sun is up. Inside, a thin man with three fingers on his right hand rattles bone dice in a leather cup."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.offer "\"Odo Three-Fingers, at your service,\" he says. \"Fifty gold a throw. Low, you lose. Middling, I pay seventy-five. Three sixes, a hundred and fifty. Five throws, and then luck needs her rest.\""
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.count "Odo keeps the tally on his remaining fingers: you have thrown {count} times."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.bet "Throw the dice ({price} gold, {uses_left} left)"
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.rolled "You lay {price} gold on the felt. The cup turns over."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.lost "Low numbers. Odo sweeps the gold away so fast it seems never to have been yours."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.won "A fair throw. Odo counts out 75 gold, slowly, as if each coin were a tooth."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.jackpot "Three sixes. Odo looks at the dice, then at you, then pays 150 gold without a word."
    python3 tools/adventure_plugin.py set-text Gamblers_Den den.spent "The cup is packed away. \"Five throws, I said,\" Odo yawns. \"Come back in another life.\""
    python3 tools/adventure_plugin.py add-pane Gamblers_Den --place den --id rules --line "\"Three dice,\" Odo says, holding them up. \"Half the time they fall low, and I keep your gold. One time in three they fall middling. One time in six, three sixes.\"" --line "\"You will say the house wins. The house says: the house has a tent to mend.\""
    python3 tools/adventure_plugin.py add-action Gamblers_Den --place den --id rules --do talk --to rules --label "Ask how the game is played"
    python3 tools/adventure_plugin.py add-action Gamblers_Den --place den --pane all --id high --prices "200,200" --when counter=den_plays:3 --label "Sit at the high table ({price} gold, {uses_left} left)" --outcome "3 |  | The dice fall badly, and the high table is a hard teacher." --outcome "1 | gold=450 | The dice fall well: 450 gold is pushed across the felt." --outcome "1 | gold=300; amulet=red | A strange throw. Odo pays 300 gold, and adds a red amulet from his own neck. \"That one I lost fairly.\"" --result "Odo draws a curtain aside. The table behind it is older than the tent. You lay down {price} gold."
    python3 tools/adventure_plugin.py set-info Gamblers_Den --description "A striped tent by the road where Odo Three-Fingers throws bone dice: five throws at 50 gold, and a high table for those who stay." --license "GPL-3.0 (the game's own license; see LICENSE.txt)" --version 1.0.0 --note "A study of chance: one place whose button rolls on the plugin's own dice (the same result after a reload), with a counter of throws, a talk pane, and a second game that opens after three throws. Original fiction, not official Magic canon."

Then, to see it played as text, to look for mistakes and to pack it:

    python3 tools/adventure_plugin.py walk Gamblers_Den
    python3 tools/adventure_plugin.py validate Gamblers_Den
    python3 tools/adventure_plugin.py export Gamblers_Den --out dist

add-place draws two small stand-in pictures into art/; paint your own over
them, under the same file names (the art command gives advice on
sizes). The guide explains every word: GUIDE/sites.html and
GUIDE/cheatsheet.html.

THE FILES
  plugin.json   the manifest: kind "sites", id, name, version, api_version 3
  sites.json    the place: its picture, map sprite, panes and buttons,
                the roll's outcomes and the counter of throws
  text.json     every sentence, title and button
  art/          the place's picture and its map sprite
