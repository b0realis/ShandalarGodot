Corpus Sites
============

A sites plugin for Shandalar (plugin API 2), made with tools/adventure_plugin.py new
--kind sites: one place, a wayside shrine on the mainland and on every island.

Edit the JSON files, then check and package the plugin:
    python3 tools/adventure_plugin.py validate corpus_sites
    python3 tools/adventure_plugin.py export corpus_sites --out dist
Put the zip (or this folder) in the game's expanded_adventure/ folder and tick it
in the Embark window's plugin list. The guide in expanded_adventure/GUIDE/
(sites.html) explains every file and field.
