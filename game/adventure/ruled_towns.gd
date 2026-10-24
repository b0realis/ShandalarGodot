class_name RuledTowns
extends RefCounted
## A TOWN A WIZARD RULES, AND FREEING IT (1997's `VisitTownSlot` ruled path,
## visitLocation.c:4172–4345; part B, 2026-10-23), headless: what the town
## holds at each entry ([method enter]), the duel ([method duel_config]) and
## what it leaves ([method settle]). The words and stakes are shown by the
## town's own pane ([VisitPane], the `ruled` place); the duel and its end by
## [RuledTownPane].
##
## THE CONTRACT with the world screen ([method WorldScreen._open_ruled_duel]):
## the ruled town's pane offered "Duel the creature."; the world screen calls
## [method open] with the town's site slot. [method open] puts the town's
## duel over the world and returns it (a Control child of [param screen];
## while it lives the world waits) — it emits `finished(result: int)` once
## (1 the town freed, 0 lost, −1 drawn, 2 no duel; and 3, GAME_OVER, see
## below) and frees itself. The world screen then leaves the town as 1997
## did: back on the map, the clock raised and the adventure saved. null from
## [method open] means no duel could be held: the town is left at once.
##
## EVERY ENTRY (the town's pane opening, [method VisitPane._ready] — never
## [method VisitPane.describe], which also names the place for the pointer's
## tip), in 1997's order:
##  1. THE GAME IS OVER when the deck in use holds no card to stake — no card
##     but basic lands (`ExitIfNoUsableDeckCards`, visitLocation.c 2252, as
##     played: merely entering a ruled town ends the game). The town's pane
##     then shows nothing and takes its one door at once ("duel"); [method
##     open] gives the pane of the end ([RuledTownPane]: `game_over`,
##     `@QUESTFAILED` 0, 1, 4, 5), which finishes with GAME_OVER (3,
##     [constant EncounterPane.GAME_OVER]): THE WORLD SCREEN'S `finished`
##     HANDLER shows the adventure's end for it (part B, W7), not saving.
##  2. THE HERO'S STAKE ([method stake]): (town x mod 3) + 1 cards, the same
##     every entry — 1997's seed walk over the collection: a seed at the
##     town's y, then slot = seed mod 500, seed += 7, until a slot holds a
##     card of the deck in use that is not a basic land (`deck & 0x4000`
##     clear, card id above 4); the walk goes on from there for the next.
##     Here the collection's slots are [member AdventurePlayer.cards]' places.
##     [Ours: 1997 staked the same copy again when the deck held fewer such
##     cards than the count; the stake is capped at what is there.]
##     `@VISIT` 0 "Your ANTE".
##  3. THE CREATURE ([method creature]): [method CreatureBook.pick] of the
##     ruling wizard's colour at a tier by the siege clock (T / 128: 0 → 4,
##     1 → 6, 2 → 8, 3 → 12, 4 → 16, later 18 for a town on an odd row and 14
##     on an even one), on the adventure's dice — DRAWN AGAIN ON EVERY ENTRY.
##  4. THE CREATURE'S STAKE ([method creature_stake]): one card of its
##     maindeck (the deck 1997 loaded with no filter), not a basic land, not
##     a dungeon's treasure (`extra_ability & 0x100`), by its copies on the
##     adventure's dice (1997's `DrawRandomCardFromInitialLibrary`, external
##     to the decompilation: the weighting is ours). Unlike a meeting's, its
##     signature card may be staked. `@VISIT` 1 "Wizard's ANTE"; the
##     creature's face in the tinted frame (`Prdfrmc.pic`,
##     `preduel_frame_tinted`).
##  5. THE WORDS (`@VISIT` 2–7): "This place is ruled by the %s." (the
##     wizard), "To free the city you must duel this %s" (THE CREATURE's
##     name), " Never mind. / Duel the creature.".
##
## THE DUEL ([method meeting], [method duel_config]): the creature starts
## with ONE OF ITS WIZARD'S MINIONS IN PLAY (`g_dungeon_monster_duel_music_
## csvids`, [constant CreatureBook.MINIONS], `rand(3)` drawn as the duel is
## chosen — 1997 does not say so); it plays its maindeck (filter 0) at
## strength 3 with no hand modifier; the stakes as above (the hero's lifted
## out of the deck in use, the creature's out of its library); the lives as
## in any duel; the hero's next-duel gifts played. [Ours] The adventure is
## saved as the duel begins (b4 §8; 1997 saved only once the town was left):
## quitting mid-duel comes back to the hero standing at the town, nothing
## lost or won (the owner's ruling 4).
##
## WHAT IT LEAVES ([method settle]; every next-duel gift spent first):
##  - A WIN (result 1 only): the ruler gone ([method TownStatus.release]; the
##    mana link stays lost), the win music and `Celeb.pic` (`town_freed`),
##    "%s is freed! The people rejoice." (`@VISIT` 8); THE CREATURE'S STAKE
##    WON INTO THE DECK IN USE (`AddCardToDeckSorted` with no "no deck" mark
##    after it — every other prize goes in no deck; as played), "Acquired
##    spell" for a rare as that adder wrote; the journal "Freed %s"
##    (`JOURNAL_ENTRY_CITY_SAVED`, `@LOGSTRINGS` 2, event `freed`). No
##    victory logged, no "Defeated" line.
##  - A LOSS: the lose music; for each staked card `Losedul2.pic`
##    (`lose_card`) and "Lost this card" (`@VISIT` 9), and the card leaves
##    the collection (the copy staked, [method CreatureMeeting.lose_stake]).
##    No journal line.
## Then 1997 goes back to the map: no services, no "Visited", no visited
## mark; the creatures near the hero pushed back, the adventure saved, the
## clock on to the next 32 (the world screen's).
##
## FIXED [ours: 1997 slip, the lead's default under the owner's ruling 1]:
## A DRAW CHANGES NOTHING — the town stays ruled and the stake stays the
## hero's (1997 counted anything but 1 a loss, `RunDuelEngine(…) == 1`: a
## draw lost the stake). The words name the CREATURE ("…duel this Goblin
## Lord"), as `@VISIT` 4 is formatted with `GetCreatureName` (our pane read
## "…this Red Wizardess's creature" until part B).
##
## DESIGNED, NEVER USED (dead in 1997, dead here; for
## `docs/adventure-unused-1997-features.md`):
##  - GENDERED WORDS. `@VISIT` holds each of its ruled-town lines twice — 2/3
##    chosen by the wizard's gender (`IsWizardColorFeminine`), 4/5 and 6/7
##    by the creature's (`IsCreatureTypeFeminine`) — and every pair is the
##    same words: the choice is made and changes nothing (the meetings'
##    `@ENCOUNTER_PREDUEL` pairs are the same). Written apart ("…duel this
##    Witch, she…"), the towns would speak of the wizard and the creature as
##    the people they are. To switch on: [constant RULED_WORDS] and
##    [constant FREE_WORDS] given a second, feminine line each, chosen by
##    [method CreatureMeeting.wizard_feminine] and [method
##    CreatureBook.feminine] in [method words].
##  - THE TOWN'S CREATURE IN ROAMING SLOT 6. As the duel is chosen 1997 writes
##    the creature's row and the wizard's colour into roaming slot 6
##    (`g_lair_or_monster_slots[6]`, visitLocation.c 4290–4291) and never
##    reads them for the duel, nor clears them — a slot of the map's six
##    then holds the town's guardian, colour and kind only, at no place.
##    Perhaps meant to keep the beaten guardian on the map (it would roam out
##    of the freed town) or to count it like a roaming win; it would need a
##    place and a meaning to be switched on. Ours keeps the map's slots
##    untouched.
##  - The duel's strength 3 and colour: as the lair duels' ([LairDuels]),
##    read only by the dead hand size (§2).

## The duel's results, seen from the hero ([EncounterPane]'s).
const WON := 1
const LOST := 0
const DRAWN := -1
const NO_DUEL := 2
const GAME_OVER := 3
## The siege clock's step between the creatures' tiers, and the tiers by
## T / 128 (later: [constant LATE_TIERS], an even row's and an odd row's).
const SIEGE_STEP := 128
const TIERS: Array[int] = [4, 6, 8, 12, 16]
const LATE_TIERS: Array[int] = [14, 18]
## The seed walk: 1997's collection of 500 slots, the seed's step.
const BAG := 500
const SEED_STEP := 7
## `@VISIT`, as 1997 words it (Advstrings.txt; 0-based): 0, 1 the captions;
## 2/3 the ruler, 4/5 the creature, 6/7 the choices (each pair alike, see
## the class doc); 8 freed; 9 a card lost.
const YOUR_ANTE := "Your ANTE"
const WIZARD_ANTE := "Wizard's ANTE"
const RULED_WORDS := "This place is ruled by the %s."
const FREE_WORDS := "To free the city you must duel this %s"
const NEVER_MIND := "Never mind."
const DUEL := "Duel the creature."
const FREED := "%s is freed! The people rejoice."
const LOST_CARD := "Lost this card"
## `@LOGSTRINGS` 2.
const FREED_LOG := "Freed %s"

## THE LAST ENTRY into a ruled town, for the duel chosen from its pane
## ([method open] is handed only the town): `{player, slot, entry}` — the
## player by instance id, the entry's names only (no card objects in a
## static, CONTRIBUTING's rule).
static var _last := {}


# ------------------------------------------------------------- the entry --

## THE TOWN ENTERED: what ruled town [param slot] holds this time, drawn now
## in 1997's order (see the class doc) and kept as the last entry — `{slot,
## wizard, tier, row, hero_ante, hero_ante_at, creature_ante, no_ante}`;
## `no_ante` true (and nothing drawn) when the deck in use holds no card to
## stake. `{}` for a town no wizard rules. [param again]: the town opened
## again where the hero stands — its last entry kept, nothing drawn.
static func enter(player: AdventurePlayer, slot: int, again := false) -> Dictionary:
	var world := player.world if player != null else null
	if world == null or not TownStatus.ruled(world, slot):
		return {}
	# The town opened again where the hero stands (the world screen's entry
	# latch [ours]): what the dice drew as the hero walked in — the creature
	# and its stake — kept, no dice drawn again; the hero's own stake and the
	# game's end read again from the deck as it is now (it may have changed
	# meanwhile — Conjurer's Will, a card lost to a creature — and the stake
	# walk draws no dice). A duel already held took the entry.
	if again and not _last.is_empty() and int(_last["slot"]) == slot \
			and int(_last["player"]) == player.get_instance_id():
		var kept: Dictionary = _last["entry"]
		kept["no_ante"] = CreatureMeeting.usable_cards(player).is_empty()
		var staked := stake(player, slot) if not kept["no_ante"] else {"names": [] as Array[String], "places": [] as Array[int]}
		kept["hero_ante"] = staked["names"]
		kept["hero_ante_at"] = staked["places"]
		if not kept["no_ante"] and int(kept.get("row", 0)) == 0:
			# Arrived with nothing to stake, a card in the deck since: the
			# creature and its stake are drawn now, as on a first entry.
			return enter(player, slot)
		return kept
	var entry := {"slot": slot, "wizard": TownStatus.ruler(world, slot), "tier": tier(player, slot),
		"row": 0, "hero_ante": [] as Array[String], "hero_ante_at": [] as Array[int],
		"creature_ante": [] as Array[String], "no_ante": false}
	if CreatureMeeting.usable_cards(player).is_empty():
		entry["no_ante"] = true
	else:
		var staked := stake(player, slot)
		entry["hero_ante"] = staked["names"]
		entry["hero_ante_at"] = staked["places"]
		var row := creature(player, slot)
		entry["row"] = row
		var dice := MsvcRandom.new(player.dice)
		var card := creature_stake(row, dice)
		player.dice = dice.state
		if card != "":
			(entry["creature_ante"] as Array[String]).append(card)
	_last = {"player": player.get_instance_id(), "slot": slot, "entry": entry}
	return entry


## The last entry into town [param slot] by [param player] ([method enter]),
## taken (a duel is held once an entry); `{}` when it is not the last one.
static func entered(player: AdventurePlayer, slot: int) -> Dictionary:
	if player == null or _last.is_empty() or int(_last["slot"]) != slot \
			or int(_last["player"]) != player.get_instance_id():
		return {}
	var entry: Dictionary = _last["entry"]
	_last = {}
	return entry


## Forget the last entry (a test).
static func forget() -> void:
	_last = {}


## How many cards the hero stakes at town [param slot]: (its x mod 3) + 1.
static func stake_count(world: ShandalarWorld, slot: int) -> int:
	if world == null or slot < 0 or slot >= world.sites.size():
		return 0
	return posmod(int(world.sites[slot]["x"]), 3) + 1


## THE HERO'S STAKE at town [param slot]: 1997's seed walk (see the class
## doc) — `{names, places}`, the cards and their places in [member
## AdventurePlayer.cards]; the same for the same collection every entry.
## [Ours: 1997 slip — a deck with fewer such cards than the count staked one
## copy again; capped here at the cards there are.]
static func stake(player: AdventurePlayer, slot: int) -> Dictionary:
	var names: Array[String] = []
	var places: Array[int] = []
	var world := player.world
	var usable: Array[int] = []
	for at in CreatureMeeting.usable_cards(player):
		if at < BAG:
			usable.append(at)
	var count := mini(stake_count(world, slot), usable.size())
	if count > 0:
		var seed := int(world.sites[slot]["y"])
		# The walk visits every slot in 500 steps (7 and 500 share no
		# factor): it finds each card in at most that.
		var steps := 0
		while places.size() < count and steps < BAG * (count + 1):
			var at := posmod(seed, BAG)
			seed += SEED_STEP
			steps += 1
			if at in usable and not at in places:
				places.append(at)
				names.append(String(player.cards[at]["card"]))
	return {"names": names, "places": places}


## The creature's tier at town [param slot] by the siege clock (see the
## class doc).
static func tier(player: AdventurePlayer, slot: int) -> int:
	var step := maxi(player.siege_timer, 0) / SIEGE_STEP
	if step < TIERS.size():
		return TIERS[step]
	var y := int(player.world.sites[slot]["y"]) if player.world != null else 0
	return LATE_TIERS[1] if y & 1 != 0 else LATE_TIERS[0]


## THE CREATURE of ruled town [param slot]: of its wizard's colour at
## [method tier], on the adventure's dice ([method CreatureBook.pick]; 0 —
## the lair — after 999 draws that fit nothing, which no wizard's tier here
## comes to).
static func creature(player: AdventurePlayer, slot: int) -> int:
	var dice := MsvcRandom.new(player.dice)
	var row := CreatureBook.pick(dice, TownStatus.ruler(player.world, slot), tier(player, slot))
	player.dice = dice.state
	return row


## THE CREATURE'S STAKE: one card of creature [param row]'s maindeck, a copy
## at a time alike ([param dice]), never a basic land, a dungeon's treasure
## or a card the game does not know; "" when its deck holds none.
static func creature_stake(row: int, dice: MsvcRandom) -> String:
	if row <= 0:
		return ""
	var treasures := {}
	for treasure in ShandalarWorld.DUNGEON_CARDS:
		treasures[String(treasure[1])] = true
	var pool: Array = []
	var total := 0
	for entry in CreatureDeck.library(row, 0):
		var card_name := String(entry["name"])
		if not bool(entry["known"]) or card_name in CreatureDeck.BASICS or treasures.has(card_name) \
				or int(entry["count"]) <= 0:
			continue
		pool.append(entry)
		total += int(entry["count"])
	if total == 0:
		return ""
	var at := dice.below(total)
	for entry in pool:
		at -= int(entry["count"])
		if at < 0:
			return String(entry["name"])
	return ""


## THE TOWN'S WORDS for [param entry] (`@VISIT` 2–5): the ruler, and the
## creature to duel by its name.
static func words(player: AdventurePlayer, entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var wizard := int(entry.get("wizard", 0))
	if wizard < 1:
		return out
	out.append(RULED_WORDS % WorldNames.WIZARDS[wizard - 1])
	var row := int(entry.get("row", 0))
	if row > 0:
		out.append(FREE_WORDS % CreatureBook.name_of(row))
	return out


## The choices (`@VISIT` 6): Never mind, Duel the creature — `[id, words,
## ready]` (the duel not ready with no creature).
static func choices(entry: Dictionary) -> Array:
	return [["leave", NEVER_MIND, true], ["duel", DUEL, int(entry.get("row", 0)) > 0]]


## The minion creature [param wizard]'s town creature starts with in play:
## one of the wizard's three ([constant CreatureBook.MINIONS]) by `rand(3)`.
static func minion(wizard: int, dice: MsvcRandom) -> String:
	var three: Array = CreatureBook.MINIONS.get(clampi(wizard, 1, 5), [])
	if three.is_empty():
		return ""
	return String(three[dice.below(three.size())])


# -------------------------------------------------------------- the duel --

## THE DUEL CHOSEN: the meeting record the duel is built from
## ([method CreatureMeeting.meet]'s shape, set as 1997 set it,
## visitLocation.c 4286–4301) — the minion drawn now; the stakes the
## entry's; strength 3, no hand modifier, the maindeck (filter 0), nothing
## special.
static func meeting(player: AdventurePlayer, entry: Dictionary) -> Dictionary:
	var row := int(entry.get("row", 0))
	var wizard := int(entry.get("wizard", 1))
	var dice := MsvcRandom.new(player.dice)
	var card := minion(wizard, dice)
	player.dice = dice.state
	var slot := int(entry.get("slot", -1))
	var at := player.position
	if player.world != null and slot >= 0 and slot < player.world.sites.size():
		var site: Dictionary = player.world.sites[slot]
		at = Vector2i(int(site["x"]) * 32 + 16, int(site["y"]) * 32 + 16)
	return {"slot": -1, "row": row, "met_row": row, "color": wizard, "kind": CreatureBook.kind(row),
		"at": at, "relation": CreatureMeeting.NONE, "wins": 0, "strength": 3,
		"base_strength": CreatureBook.base_strength(row), "bribe": 0, "quest": false,
		"hero_ante": (entry.get("hero_ante", []) as Array).duplicate(),
		"hero_ante_at": (entry.get("hero_ante_at", []) as Array).duplicate(),
		"creature_ante": (entry.get("creature_ante", []) as Array).duplicate(), "no_ante": false,
		"sleight_used": false, "timer": player.monster_timer, "prepared": true,
		"total_wins": player.total_wins(), "modifier": 0, "filter": 0, "special": false,
		"events": [] as Array[String], "swap_row": 0, "summoned": 0, "card": card,
		"first_strike": false, "mind_control": false, "town": int(entry.get("slot", -1))}


## THE DUEL HANDED TO THE ENGINE ([method CreatureMeeting.duel_config] for
## the record of [method meeting]): the hero's deck in use, padded, the
## stake lifted out of it; the creature's maindeck, its stake lifted out of
## it; the minion in play; the lives as in any duel.
static func duel_config(player: AdventurePlayer, met: Dictionary) -> DuelConfig:
	return CreatureMeeting.duel_config(player, met)


# ------------------------------------------------------------- the end --

## THE DUEL SETTLED from [param report] ([param conceded]: a loss): every
## next-duel gift spent, then the town freed, the stake lost, or — a draw —
## nothing (see the class doc). `{result, town, name, card, kept, lost,
## words}`: `card` the creature's stake won ("" none), `kept` whether the bag
## held it, `lost` the hero's cards lost.
static func settle(player: AdventurePlayer, met: Dictionary, report: DuelReport,
		conceded := false) -> Dictionary:
	var result := LairDuels.result_of(report, conceded)
	var slot := int(met.get("town", -1))
	var town := WorldNames.site_name(player.world, slot)
	var out := {"result": result, "town": slot, "name": town, "card": "", "kept": false,
		"lost": [] as Array[String], "words": [] as Array[String]}
	player.clear_duel_gifts()
	match result:
		WON:
			TownStatus.release(player.world, slot)
			var stakes: Array = met.get("creature_ante", [])
			if not stakes.is_empty():
				out["card"] = String(stakes[0])
				out["kept"] = player.add_card(String(stakes[0]))
				if bool(out["kept"]):
					# Into the deck in use, as 1997's adder put it.
					(player.cards[-1] as Dictionary)["decks"] = [player.current_deck]
			player.log_event("freed", FREED_LOG % town, {"town": slot})
			(out["words"] as Array[String]).append(FREED % town)
		LOST:
			out["lost"] = CreatureMeeting.lose_stake(player, met)
	return out


# ----------------------------------------------------------- the world --

## The duel for ruled town [param slot] over [param screen] (the contract,
## see the class doc): the entry the town's pane drew ([method entered]),
## or one drawn now; its pane ([RuledTownPane]) centred over the world, a
## card right-clicked on it read full screen; the adventure saved as the duel
## begins [ours]. null when none can be held (no such ruled town, no
## creature drawn).
static func open(screen: Node, slot: int) -> Control:
	var player: AdventurePlayer = screen.get("player") if screen != null else null
	if player == null or player.world == null or not TownStatus.ruled(player.world, slot):
		return null
	var entry := entered(player, slot)
	if entry.is_empty():
		entry = enter(player, slot)
	if not bool(entry.get("no_ante", false)) and int(entry.get("row", 0)) <= 0:
		return null
	var pane := RuledTownPane.new()
	pane.player = player
	pane.screen = screen
	pane.entry = entry
	var hud: Variant = screen.get("hud")
	if hud is WorldHud and (hud as WorldHud).big:
		pane.k = WorldHud.BIG
	screen.add_child(pane)
	PaneStyle.centre(pane)
	if screen.has_method("read_card"):
		pane.card_read.connect(func(card_name: String) -> void: screen.call("read_card", card_name))
	if not bool(entry.get("no_ante", false)) and screen.has_method("autosave"):
		screen.call("autosave")
	return pane
