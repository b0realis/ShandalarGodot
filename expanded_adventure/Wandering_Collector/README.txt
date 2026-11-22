The Wandering Collector
=======================

A sites plugin for Shandalar (plugin API 3): a new place on the mainland.

THE PLACE
Under an awning by the road sits Ysolt of the Nine Chests, who has walked
Shandalar for thirty years filling them. Eight are full. The ninth wants
three brass birds: Ornithopters, the little flying machines of the
artificers. For each one you hand over she counts out 150 gold. When the
third bird is in its place she closes the ninth chest, and gives you
something from the first.

WHAT YOU NEED
Nothing but the game: the plugin needs no card pack. An Ornithopter is found
in shops and dungeons of the base game.

A STUDY
The camp is a finished place, and a study of a cost that is not gold: the
trade button shows only while the hero holds the card (has_card), takes one
copy when pressed (needs), and pays with effects. Its three prices of 0 gold
mean "three times, free". The pane that follows the last trade carries a
gift given once. Collectors, tolls paid in amulets and quests that ask for a
card are all built this way.

HOW IT WAS MADE
Every line of its JSON was written by the game's authoring tool; nobody
edited a file by hand. These are the commands, in order, run from the
game's folder, one command a line (each says what it did and what comes
next):

    python3 tools/adventure_plugin.py new Wandering_Collector --id wandering_collector --name "The Wandering Collector" --author "Shandalar Godot" --kind sites
    python3 tools/adventure_plugin.py add-place Wandering_Collector --id wagon --name "The Collector's Camp" --recipe collector --card Ornithopter
    python3 tools/adventure_plugin.py remove-place Wandering_Collector --id shrine
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.intro "Nine iron-bound chests stand in a half circle under an awning. Among them sits a gray-haired woman, sorting cards by lamplight."
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.wants "\"Ysolt, of the Nine Chests,\" she says without looking up. \"Eight are full. The ninth wants three brass birds. Ornithopters. I pay 150 gold for each, and I do not haggle.\""
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.have "She looks up sharply. \"You have one. I can hear its wings ticking in your bag.\""
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.count "Brass birds in the ninth chest so far: {count}."
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.trade "Hand over {card} for 150 gold ({uses_left} left)"
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.traded "Ysolt takes {card} in both hands, winds it once to hear it tick, and lays it in the ninth chest. She counts out 150 gold."
    python3 tools/adventure_plugin.py set-text Wandering_Collector wagon.spent "The ninth chest is shut and locked. \"Thirty years,\" Ysolt says. \"Now I will have to think of a tenth.\""
    python3 tools/adventure_plugin.py add-action Wandering_Collector --place wagon --pane 0 --id gift --prices 0 --effect amulet=blue --effect food=4 --label "Accept her parting gift" --result "She opens the first chest, the oldest, and takes out a blue amulet wrapped in oilcloth, and bread for four days. \"For the road. You carried my birds; let these carry you.\""
    python3 tools/adventure_plugin.py set-info Wandering_Collector --description "A collector's camp by the road: she pays 150 gold for each Ornithopter you hand over, three in all, and then gives a parting gift." --license "GPL-3.0 (the game's own license; see LICENSE.txt)" --version 1.0.0 --note "A study of barter: one place that sees a card in the hero's bag, takes it as the price, and pays for it, with a counter of trades and a gift when the set is whole. Original fiction, not official Magic canon."

Then, to see it played as text, to look for mistakes and to pack it:

    python3 tools/adventure_plugin.py walk Wandering_Collector
    python3 tools/adventure_plugin.py validate Wandering_Collector
    python3 tools/adventure_plugin.py export Wandering_Collector --out dist

add-place draws two small stand-in pictures into art/; paint your own over
them, under the same file names (the art command gives advice on
sizes). The guide explains every word: GUIDE/sites.html and
GUIDE/cheatsheet.html.

THE FILES
  plugin.json   the manifest: kind "sites", id, name, version, api_version 3
  sites.json    the place: its picture, map sprite, panes and buttons,
                the card it asks for and the counter of trades
  text.json     every sentence, title and button
  art/          the place's picture and its map sprite
