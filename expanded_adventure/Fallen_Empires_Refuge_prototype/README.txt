The Last Refuge (Fallen Empires prototype)
==========================================

An adventure plugin for Shandalar: an island of Sarpadian refugees, reached
by ship from a mainland harbor.

A GAME-DESIGN AND LEARNING DEMO
This plugin is a game-design and learning demo. Its island, people, quests
and foes are original fiction made for the game: not official Magic canon
and not new official content. It is finished and playable, and it shows
every part of the plugin format in one place, so that plugin authors can
play it, read it and take it apart. The game adds no other adventure
content of its own; new lands are for the community to make.

WHAT YOU NEED
- Card pack 2, Fallen Empires, installed. The plugin names the pack it
  needs; the pack's cards behave as they do without the plugin.
- At the Embark, open "Expanded adventure plugins..." and tick this plugin.
  Ticking it ticks Pack 2 as well.

THE STORY
The ship from a mainland harbor sails to the Last Refuge. Five communities
there resist the Ebon Crown: Leitbur's Rest, Vodalian Haven, the Freehold
of the Hand, Dwarven Hearth and Havenwood. Win each community's pledge,
then challenge the Lord of the Ebon Crown in the island's central castle.
The final battle needs all five pledges and a main deck whose nonland
cards are at least half Fallen Empires cards. Each pledge earns gold, food
and six Fallen Empires cards in a color you choose. Passage home is always
free, and your progress waits while you are away.

It is a dangerous land: the Crown's commanders have 26 to 30 life, its lord
36, and the roaming creatures are strong. Build your deck on the mainland
first.

THE FILES (each is described in the guide, GUIDE/index.html)
  plugin.json   the manifest: id, name, version, the card pack it needs
  world.json    the island's recipe: towns, places, villages, roads
  places.json   the harbor and the castle: pictures, map sprites, panes
  quests.json   the five petitions, their steps, the finale, the talk
  foes.json     the duel opponents and the roaming creatures' decks
  rewards.json  the reward bundles, one per color
  text.json     every sentence, title and button
  art/          the harbor and castle pictures and map sprites

The plugin is data only: the game reads these files and never runs
anything from them. It holds no card pictures.

LICENSE: GPL-3.0, the game's own; see LICENSE.txt.
