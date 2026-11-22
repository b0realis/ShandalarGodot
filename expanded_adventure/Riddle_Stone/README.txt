The Riddle Stone
================

A sites plugin for Shandalar (plugin API 3): a new place on the mainland.

THE PLACE
On a low hill stands a stone taller than a rider, older than the roads.
Words are cut into it, and they are a question. Three answers are cut
beneath, each beside a hollow worn by many hands. Lay your hand in the right
hollow and the stone pays what the last wrong traveler left behind. Lay it
in a wrong one and nothing happens, except that the stone remembers. Those
who have failed twice may put an ear to the rock, and hear something that
helps.

WHAT YOU NEED
Nothing but the game: the plugin needs no card pack. At the Embark, open
"Expanded adventure plugins..." and tick it.

A STUDY
The stone is a finished place, and a study of conversation without any new
machinery: each answer is a talk button that opens a pane with an id. A
wrong answer adds one to a counter; the right one sets a flag and pays gold
once. A fourth button shows only when the counter has reached two. Lore
pages, quizzes and branching talk are all built this way.

HOW IT WAS MADE
Every line of its JSON was written by the game's authoring tool; nobody
edited a file by hand. These are the commands, in order, run from the
game's folder, one command a line (each says what it did and what comes
next):

    python3 tools/adventure_plugin.py new Riddle_Stone --id riddle_stone --name "The Riddle Stone" --author "Shandalar Godot" --kind sites
    python3 tools/adventure_plugin.py add-place Riddle_Stone --id stone --name "The Riddle Stone" --recipe riddle
    python3 tools/adventure_plugin.py remove-place Riddle_Stone --id shrine
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.intro "A standing stone on a low hill, taller than a rider. Words are cut deep into its face, and beneath them three hollows worn smooth by many hands."
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.riddle "\"Every wizard carries me, and I weigh nothing. Spent at dusk, I am back by dawn. Without me the mightiest spell is only a word. What am I?\""
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.tries "The stone remembers: you have answered wrongly {count} times."
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.answer_a "Lay your hand in the first hollow: \"A name.\""
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.answer_b "Lay your hand in the second hollow: \"Mana.\""
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.answer_c "Lay your hand in the third hollow: \"A shadow.\""
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.wrong "The hollow is cold under your palm, and stays cold. Somewhere inside the rock, something settles, like a sigh."
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.right "The hollow grows warm. A seam opens in the rock, and 100 gold spills out: the offerings of everyone who guessed before you."
    python3 tools/adventure_plugin.py set-text Riddle_Stone stone.silent "The words have faded to a shadow on the rock. The stone has asked its question and been answered."
    python3 tools/adventure_plugin.py add-pane Riddle_Stone --place stone --id hint --line "You press your ear to the rock. Far inside, a voice like a spring under ice: \"Think of what your lands give you, traveler, each morning.\""
    python3 tools/adventure_plugin.py add-action Riddle_Stone --place stone --id listen --do talk --to hint --when counter=stone_tries:2 --when not_flag=stone_solved --label "Put your ear to the stone"
    python3 tools/adventure_plugin.py set-info Riddle_Stone --description "A standing stone that asks one riddle: three answers, a hint for those who fail twice, and 100 gold for the right one." --license "GPL-3.0 (the game's own license; see LICENSE.txt)" --version 1.0.0 --note "A study of talk: one place whose answers are buttons that open named panes, with a counter of wrong answers and a hint that appears after two. Original fiction, not official Magic canon."

Then, to see it played as text, to look for mistakes and to pack it:

    python3 tools/adventure_plugin.py walk Riddle_Stone
    python3 tools/adventure_plugin.py validate Riddle_Stone
    python3 tools/adventure_plugin.py export Riddle_Stone --out dist

add-place draws two small stand-in pictures into art/; paint your own over
them, under the same file names (the art command gives advice on
sizes). The guide explains every word: GUIDE/sites.html and
GUIDE/cheatsheet.html.

THE FILES
  plugin.json   the manifest: kind "sites", id, name, version, api_version 3
  sites.json    the place: its picture, map sprite, panes and buttons,
                its named panes, flag and counter
  text.json     every sentence, title and button
  art/          the place's picture and its map sprite
