The Duelist's Ring
==================

A sites plugin for Shandalar (plugin API 3): a new place on the mainland.

THE PLACE
Where two roads cross, ropes mark a square of trampled grass, and there is
always a crowd. Marda Ironhand takes all comers: fifty gold says you cannot
beat her, a hundred back if you do, three bouts and no more. Brannoch the
Ringmaster watches from his stool and says nothing. Win twice, and he stands
up, folds his coat, and offers a bout of his own for a hundred and fifty
against four hundred.

WHAT YOU NEED
Nothing but the game: the plugin needs no card pack. You need a deck, as for
any duel.

A STUDY
The ring is a finished place, and a study of the duel action: the price is
the stake, paid as the duel begins (a duel left unfinished is a duel lost),
win and lose each have their own effects and words, and a counter of wins
opens the second opponent. The two opponents' decks are plain lists,
champion_deck.txt and ringmaster_deck.txt, one card a line; the add-foe
command read them into sites.json. An opponent's deck, life and face are
fixed, never scaled to the hero.

HOW IT WAS MADE
Every line of its JSON was written by the game's authoring tool; nobody
edited a file by hand. These are the commands, in order, run from the
game's folder, one command a line (each says what it did and what comes
next):

    python3 tools/adventure_plugin.py new Duelists_Ring --id duelists_ring --name "The Duelist's Ring" --author "Shandalar Godot" --kind sites
    python3 tools/adventure_plugin.py add-place Duelists_Ring --id ring --name "The Duelist's Ring" --recipe duelist
    python3 tools/adventure_plugin.py remove-place Duelists_Ring --id shrine
    python3 tools/adventure_plugin.py add-foe Duelists_Ring --id ring_champ --replace --name "Marda Ironhand" --life 20 --face 30 --deck Duelists_Ring/champion_deck.txt --deck-name "Ironhand's Hammer"
    python3 tools/adventure_plugin.py add-foe Duelists_Ring --id ringmaster --name "Brannoch the Ringmaster" --life 25 --face 40 --deck Duelists_Ring/ringmaster_deck.txt --deck-name "The Ringmaster's Own"
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.intro "Ropes mark a square of trampled grass where two roads cross. A crowd stands three deep around it, and coins change hands before anyone has moved."
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.offer "A broad woman with a scarred forearm leans on the ropes. \"Marda Ironhand. Fifty gold says you cannot beat me. Win, and you take a hundred. Three bouts, no more: I have a living to make.\""
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.wins "The crowd knows you now: you have won {count} bouts in this ring."
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.duel "Wager {price} gold against {foe} ({uses_left} left)"
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.won "The crowd roars. {foe} spits, laughs, and pays you 100 gold. \"Fairly done.\""
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.lost "{foe} pockets your wager and helps you up. \"Come back when you have learned something.\""
    python3 tools/adventure_plugin.py set-text Duelists_Ring ring.spent "The ropes are coiled and the crowd has drifted off. Marda is counting her takings and does not look up."
    python3 tools/adventure_plugin.py add-action Duelists_Ring --place ring --pane all --id master --do duel --foe ringmaster --prices 150 --when counter=ring_wins:2 --label "Accept the Ringmaster's own bout ({price} gold against {foe})" --win-effect gold=400 --win-effect counter=ring_wins+1 --win "{foe} bows, deeply, for the first time in years. He pays 400 gold from his own purse, and the crowd carries you twice around the ring." --lose "{foe} folds his coat back over his arm. \"You fought well. Not well enough.\" Your 150 gold stays with him."
    python3 tools/adventure_plugin.py set-info Duelists_Ring --description "A roped ring where Marda Ironhand duels for a wager of 50 gold; beat her twice and the Ringmaster himself steps in." --license "GPL-3.0 (the game's own license; see LICENSE.txt)" --version 1.0.0 --note "A study of duels: one place whose button stakes gold on a duel against the plugin's own opponent, with a counter of wins that opens a second, harder duel. Original fiction, not official Magic canon."

Then, to see it played as text, to look for mistakes and to pack it:

    python3 tools/adventure_plugin.py walk Duelists_Ring
    python3 tools/adventure_plugin.py validate Duelists_Ring
    python3 tools/adventure_plugin.py export Duelists_Ring --out dist

add-place draws two small stand-in pictures into art/; paint your own over
them, under the same file names (the art command gives advice on
sizes). The guide explains every word: GUIDE/sites.html and
GUIDE/cheatsheet.html.

THE FILES
  plugin.json   the manifest: kind "sites", id, name, version, api_version 3
  sites.json    the place: its picture, map sprite, panes and buttons,
                its two opponents and their decks, the counter of wins
  text.json     every sentence, title and button
  art/          the place's picture and its map sprite
  champion_deck.txt, ringmaster_deck.txt
                the two deck lists add-foe read (kept here to be studied)
