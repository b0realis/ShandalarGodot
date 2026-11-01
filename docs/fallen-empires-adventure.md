# Fallen Empires — The Last Refuge

Playable prototype on `2nd_pack`. This is an optional island journey alongside
Shandalar's main adventure. It does not replace a guild lord, original town,
dungeon, or main-quest destination.

## Story and lore

Fallen Empires takes place in ancient Sarpadia on Dominaria. Its five cultures
and their conflicts inspire this expansion; the historical Sarpadian continent
is not an island of Shandalar.

Our new story imagines that refugees reached Shandalar through a passage before
the Great Barrier was raised. That passage is long closed. Their descendants
live on an island within Shandalar, reachable by an ordinary sea voyage.
The Lord of the Ebon Crown, a new character descended from the traditions of
the Ebon Hand, now demands their harvests and controls the roads. The hero
helps the communities build a common future instead of repeating their
ancestors' destruction.

This refuge, its settlements, surviving communities, lord and quests are
original game fiction, not an assertion about published Magic continuity.
Wizards' account of the set's
[paired factions](https://magic.wizards.com/en/news/making-magic/faction-packed-2018-10-15)
is the historical basis: Icatian soldiers and zealots, Vodalians and homarids,
the Ebon Hand and thrulls, dwarves and their orc/goblin enemies, and elves
and thallids. Cooperation on our island is a new choice made by these fictional
communities, not a rewrite of Sarpadia's wars. The refugees' crossing is undated;
it is not presented as an event documented in published Magic stories.

## Playing the journey

Enable **Pack 2: Fallen Empires** in Options. Open an existing adventure or
begin a new one. On the full map, **Ship: The Last Refuge** marks Sarpadian Anchorage, a reachable
coastal site clear of existing towns and encounters. Walk to it and choose
**Sail to the Island**. The other choice is **Mindfully leave the coastal town**.
Passage is free, including every return trip.

With Pack 2 disabled or missing, Sarpadian Anchorage is absent: no town on the
mainland, no map or minimap marker, and no visit or enable-pack prompt. A fresh
campaign creates no harbor until the pack is enabled. Existing harbor coordinates
and island progress are kept, so re-enabling the pack restores the same journey.

The island occupies a 32 × 32 tile footprint, one quarter of the mainland's
64 × 64 area. It samples the existing terrain generator and keeps one connected
landmass. Each seed places the five communities in varied positions, a return
harbor, a central castle, six to nine villages, four additional trading towns
and two cities. The additional towns use the mainland's temple, oasis, bazaar,
shrine, tower and mill names and services. All eleven color/type trade categories
are represented. New islands offer three randomly selected World Magics, rather
than compressing all eleven missing powers into one small map. Previously visited
islands retain their saved layout and sellers.

Roads connect neighboring settlements rather than radiating from the harbor.
They favor lowlands over mountains and swamps, reuse shared lanes, and bend
with a seeded terrain cost field in all eight directions. Diagonal roads cannot
cut across a water corner. Every settlement and the castle remain connected.
Walking, food, encounters, map controls, shops, trading, deck editing and duels
use the existing adventure systems.

The island wears a dry coastal terrain palette: sun-bleached grass, olive
foliage and a richer blue sea. It recolors vegetation and water in cached
copies of the chosen skin's terrain sheets, including coast edges, and matches
the map and minimap. Sand, stone, buildings, characters and interface art keep
their own colors. Original and
upscaled skins keep their pixel detail, transparency and drawn sizes. This is
regional presentation only; it changes no terrain types, movement or mana, and
also applies to islands already saved. The mainland retains its skin's palette.
The reusable [terrain palette API](terrain-palettes.md) provides named
Shandalar and Last Refuge presets, terrain-type overrides and individual-tile
tints for future regions.

Extra settlements offer the mainland's ordinary local quests, tracked separately
from mainland errands and the five pledges. The **Tasks** tab beside Journal
lets you select a task, pledge, known dungeon, siege or main-story goal. The guide
arrow follows that selection and updates as it progresses. A goal in another
region points to the appropriate ship. Roaming targets with unknown locations
do not get an invented arrow. Automatic guidance prioritizes an urgent errand. The map lists all five unfinished
petitions, including delivery and confrontation destinations. Pledge quests may be
completed in any order.

The Tasks tab is shared with the vanilla campaign; no expansion pack is required.
New tasks appear first. Completed tasks carry a green check and remain at the
bottom under **Finished tasks**, including after saving and loading. Expired or
failed tasks stay there with a red status. Click a task's circle-and-dot icon or
title to guide the help arrows toward it. The selected task shows a colored arrow and
**Tracking task…**, matching the map's guidance color: gold normally, red for a
siege. The floating quest panel remains a status display; task selection is in
the Tasks tab and works while the quest panel is open. Timed town errands show
campaign days remaining; sieges show their remaining clock steps.
Timers turn amber, then red as time runs short. Tasks in an inactive region show
a blue **PAUSED while away** label. Pledges have no deadline.

For playtesting, the debug launcher (`--debug-win`) enables **Ctrl+Shift+2** on
the adventure map. With Pack 2 enabled, this moves the hero beside Sarpadian
Anchorage, where the captain offers passage to the Last Refuge. Close any duel
or encounter first. The shortcut adds no rewards, spends no campaign time and
does not enable a missing or disabled pack. It also works when returning from
the island. Normal launches do not enable the shortcut.

| Community | Quest | What changes |
| --- | --- | --- |
| Leitbur's Rest | The Bread Road | Carry a grain warrant to Refuge Harbor, then return to defeat the tithe-collector. |
| Vodalian Haven | A Harbor for Both Peoples | Survey the shared channel at a coastal town or city, then return to defeat the captain. |
| Freehold of the Hand | No More Masters | Defeat the overseer trying to enslave the thrulls again. |
| Dwarven Hearth | The Mountain Road | Seek and defeat the tribute-raider at a road village near mountains. |
| Havenwood | Room to Grow | Defeat the Crown's sporekeeper, whose unchecked growth threatens the elves' and thallids' border. |

Each community's battle uses the full duel screen, normal difficulty selection
and a Fallen Empires deck. These battles stake no ante, have no deadline and
do not require a Fallen Empires deck from the hero. As in ordinary adventure
duels, a short deck receives temporary basic lands for that duel; the collection
is unchanged. Unavailable cards must be restored or removed before a challenge
can start. Victory grants its
pledge and **six cards in a chosen color, 40 gold and 8 food**, once only.
Any pledge may teach any color, so repeated rewards can support a focused deck.
Classic copy limits include both owned cards and rewards waiting for bag space.
A color with too few eligible cards cannot be chosen; the choice remains owed.
Cards that
do not fit the bag remain available for collection at a community or castle.
Defeat or a draw grants no reward; the challenge can be attempted again.
Each completed petition has its own ending describing the community's new
agreement. A small pennant appears above its settlement. Revisiting it cannot grant its reward again.

The final lord requires all five pledges and **at least half of the main deck's
nonland card copies to be Fallen Empires cards**. All lands, including nonbasic
lands from Fallen Empires, are excluded from both counts; sideboards do not
count either. A deck with no nonlands does not qualify. A selected printing
does not change membership. For example, 12 Fallen Empires nonlands among
24 nonlands meet the requirement, regardless of the number of lands.
The first harbor visit explains this gate and the danger. The adventure deck
builder shows the active deck's live count on the island. The castle shows how many of the deck's nonlands are from the set, followed
by the minimum required (rounded up for odd totals). Defeating the lord unlocks
Fallen Empires
cards in mainland shops as they restock, trades and ordinary card rewards.
It does not defeat any mainland wizard or finish the main quest. After liberation,
the castle flies a gold pennant and both harbors acknowledge the victory; the castle no longer asks
for pledges or a qualifying deck.

## Exploring beyond the communities

One dungeon, **Vaults of the First Crossing**, is placed away from roads and
settlements. Its entrance is known on arrival; its other clues can come from
wise men, ruined towers and defeated creatures. It uses the full existing
dungeon board: rooms, creatures, treasure, dice, riddles, special rules and
duels. Leaving it moves the entrance to another free tile on the island, as
mainland dungeons do. The dungeon is optional and grants no community pledge.
Its treasures are the first travelers' keepsakes, not a portal to Dominaria.

The mainland's roaming creatures and random lairs remain active. Island roamers
have a minimum strength tier of 12. Many roaming encounters use fixed local
Icatian, Vodalian, Ebon, goblin or thallid decks and 26–30 life. Their tribute
spell choices and ante come from the same deck they play. Summoners, deck-swap
meetings and named hunts retain their original decks; ordinary quest creatures retain their exact
identity so hunts remain completable. Petition opponents have 26–30 life; the
lord has 36. Their themed decks include useful core support, and the red deck
has twelve cheap goblins to fuel Grenade and Warrens. Strength stays fixed when
the hero improves; the chosen standard AI difficulty remains fair. A new hero
is encouraged to retreat and return with more life and a stronger collection. All fourteen
special lair events are available, including the Nomad's Bazaar, Oasis of
Muldoon, Gemcutter's Guild, Diamond Mine, ruined and loremaster towers, shrines,
the Dragon's Lair and the Lost City, alongside ordinary treasure sites.
They appear through the existing encounter system rather than being permanent
towns. Under Notice, creatures wander until the hero enters their range;
under Hunt they pursue directly. Dedicated friendly roaming characters are
not part of this version.

Island wise men offer seven short local tales, useful gifts and news of the
communities, local communities and World Magic sellers. They do not direct the
hero to mainland wizard castles as if those castles stood on the island.
Roaming challengers likewise use regional dialogue. Ordinary island treasure,
lair hoards and card rewards can include Fallen Empires cards; liberation
extends that pool to the mainland while Pack 2 is enabled.

## Saves and compatibility

Save format 6 keeps one active map, value snapshots of visited inactive maps,
and separate progress for each expansion. Unvisited maps are not generated.
Lightweight descriptors install only enabled entry locations. Quest code and
illustrations load on demand. Future lands can share an anchorage when coast
space runs out, with a destination menu rather than crowded buildings.
Inventory, gold, food, hero identity, main-story flags, duel gifts, journal and
island progress travel with the hero, as do Quickening and lifetime totals for
elapsed days, explored lairs and sieges. Each region keeps its exploration,
shops, creatures, position, quests and local clocks. Mainland siege and quest clocks
pause while the hero is away; the island has no guild sieges.
Mainland mana links remain effective on the island. Island quests and settlements
grant no mana links; old prototype island links no longer add life. World Magics,
amulets, other rewards, gold, food and trading retain their existing behavior. The journal labels each new entry with its cumulative day and region.
Short wise-man clues are blue; quest guidance is gold and explicitly labeled.
Repeated clues are not duplicated. Entries from another region never pin a false
location on the current map. Older entries retain their recorded day, explicitly
labeled as a region day; no historical travel dates are invented. Travel and quest results autosave through the existing
save writer. Earlier version 1–5 saves still load; version 4 counters are combined once.
Existing pledges, promised cards and old region layouts remain intact; older game binaries do not
understand the new region records, so keep a backup when testing this branch.
Already generated islands retain their saved layout and stock. The expanded
settlements, terrain-following roads and dungeon are generated on a first voyage
in a campaign that has not yet visited the island.

If Pack 2 is disabled or missing, a hero already on the island can still use
the return harbor and sail home. Arrival returns to ordinary mainland terrain,
without opening a hidden town's visit panel. New outward voyages and island
challenges are unavailable until the pack is enabled again. Pack changes and
rescans refresh the world view, full map and minimap immediately.
Missing pack cards are not replaced with different cards. Damaged inactive maps
or malformed regional markers are rejected rather than leaving a hero without
a return map. Island records must retain a return harbor, a distinct castle and
all five community settlements. Mainland mana links are counted from the saved
settlement statuses rather than a cached regional total.

## Artwork

The four new PNGs live in `game/adventure/expansions/art/` and ship with the
feature; they do not require rebuilding an existing skin. The illustration
prompts used the original town picture as a palette and rendering reference.
The castle also used the supplied stone-fortress photograph for architecture.
Map sprites use fixed world footprints regardless of the skin's resolution.

Prompt set, each produced as a new reference-guided image:

- `refuge_harbor.png`: a wide 512:280 arrival illustration; a small coastal
  settlement with ochre stone houses, a wooden jetty and one moored sailing
  ship; muted sunset, green-blue sea, hand-painted 1997 fantasy-game look and
  restrained dithering; no lettering, interface, watermark or signature.
- `refuge_castle.png`: the same illustration format and rendering; a compact
  stone fortress inspired by the supplied photograph, a square gate tower,
  square keep and round flank tower, bridge, dark banners, muted stormy sunset;
  no lettering or interface.
- `refuge_port_map.png`: transparent isometric map sprite; a few small stone
  houses, jetty and boat, warm restrained colors, pixel-art rendering matching
  the original world settlements; no text or scenery backdrop.
- `refuge_castle_map.png`: transparent isometric fortress sprite using the
  supplied tower arrangement; ochre stone, black banners, short bridge, the
  scale and palette of the original map castles; no text or scenery backdrop.

## Scope of this first version

The five petitions resolve through one duel each and award pledges; three also
require a delivery, survey or journey to a different settlement. Older maps
without those added settlements use the existing harbor or community instead.
The central castle is an illustrated location and final duel; the optional
Vaults use a separate multiroom dungeon board. Dialogue, encounters and decks are ready for
playtesting; travel pacing and difficulty over a full human campaign still
need feedback. No released package or public release is changed by this
branch.

The [quest audit](refuge-quest-audit.md) records the reachable content, corrections
and verification for this pass.
The [card audit](refuge-card-audit.md) records the four regional availability
states, reward sources, retained original restrictions and Pack 2 rules fixes.

The developer-only `expansion_lab.sh --help` describes reusable region checks
and repeatable deck/life battle baselines. Its beacon fixture is never registered
in normal gameplay. Balance reports measure isolated duels, not a full campaign.
