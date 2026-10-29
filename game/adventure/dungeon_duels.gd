class_name DungeonDuels
extends RefCounted
## THE DUELS INSIDE A CASTLE OR A DUNGEON (part C, 2026-10-27) — 1.3's
## `RunDungeonMonsterDuel(index, slot, final)` (dungeonEncounter.c 744–915,
## the "dE" lines below; retail Palette.c 7373–7531, the same rules) and the
## board's reading of its result (dE:554–577 a room, 634–661 the castle's
## wizard), headless: from "the hero steps into a room with a creature" to
## "the board is told what happened". The board itself — the maze, the dice,
## the scroll, the treasure, moving and leaving — is [DungeonBoard]'s; a
## beaten wizard is [CastleWin]'s; the world's doors are [DungeonDoors]'.
## The panes (the creature shown before the duel, the lost card, the booted
## words) are stage C2's; the duel is held over the world by [WorldDuels],
## as every adventure duel is.
##
## THE RUN RECORD the board hands over (the contract with [DungeonBoard],
## c2 spec §12.5) — a Dictionary or an object with these fields, read and
## written by name ([method read], [method write]): `index` (0–4 a castle,
## 5–14 a dungeon), `castle`, `color` (1 black … 5 white), `rules` (the
## slot's rules word), `monsters` (five [CreatureBook] rows; [4] the castle's
## wizard), `life_pool` (read and written), `dice_card` (the card the dice
## gave for the next duel, read and spent). The card in effect is the
## world slot's (`card_in_effect`, a 1997 card id; the record's own when it
## carries one). A room's event code (3–6 the creatures 0–3, 15 the castle's
## wizard) names the creature ([method slot_of]).
##
## ONE DUEL, IN 1997'S ORDER (each step a function; the pane calls them):
##  1. [method setup] — who is met and what is said (no dice drawn): the
##     creature, `run.monsters[slot]`; a castle's MINION (dE:796–806, a
##     castle only: `n = slot + difficulty − 3`, from 0 the colour's minion
##     `clamp(n, 0, 2)` of [constant CreatureBook.MINIONS] — a dungeon never
##     has one); the CARD IN EFFECT ([constant WorldClues.EFFECT_CARDS]);
##     the words (`@DUNGEON` 15/16, 17, 18): "Exploring the Castle... / you
##     encounter a Greater Lich! / / Greater Lich has the spell Hypnotic
##     Specter! / (Gloom starts in play!)" (the Black Castle at Magician).
##     `sfx_dungeon_duel` (Dngnduel.wav) is the pane's. There is no way out:
##     the hero stepped in.
##  2. [method draw_stake] — THE HERO'S STAKE, one card (the creature stakes
##     nothing, dE:833–837): `rand(500)` over the bag until a card of the
##     deck in use that is no basic land ([method CreatureMeeting.usable_cards],
##     dE:839–846). No such card in the deck in use at all — the UNFILTERED
##     deck, as `ExitIfNoUsableDeckCards` (dE:838) counts it — is THE GAME
##     OVER ("You have no power for even an Ante!", [constant
##     CreatureMeeting.NO_ANTE]): false.
##  3. [method duel_config] — the duel handed to the engine (seat 0 the hero,
##     seat 1 the creature; built whole, the meeting's pattern —
##     [method CreatureMeeting.duel_config] — field by field, the hero's
##     playmat too, [method CreatureMeeting.hero_playmat]):
##      - THE HERO'S DECK ([method hero_deck]): the deck in use less the
##        cards the slot's rules bar ([method bars]), padded for this duel
##        with random basic lands to 30/35/40/40 by difficulty
##        ([constant CreatureMeeting.DECK_LEAST], the stake counted);
##      - the stake lifted out of it (`ante_cards[0]`); seat 1 stakes nothing;
##      - THE CREATURE'S DECK, its maindeck only (`LoadCreatureDuelDeck(row,
##        …, 0, −1)`, dE:807–808: no colour it learned —
##        [method CreatureDeck.for_meeting] with filter 0);
##      - THE LIVES: the hero's ([method hero_life]), the creature's ([method
##        creature_life]: a room creature its tier + 2 a difficulty step, a
##        henchman + its World Magics, the castle's wizard `tier 20 + 5d + 10
##        − the wins over his colour + d · his towns`, never under 5d + 20 —
##        [method CreatureBook.duel_life]);
##      - IN PLAY at the start: the creature's minion, then the card in
##        effect (D:2502–2520); the hero's next-duel cards — the world's gift
##        and the dice's;
##      - the first move: the hero with the world's first-move gift, else
##        1997's coin; 1997's mulligan; the computer choosing play or draw at
##        random; the computer at the hero's difficulty.
##  4. [method settle] — what the duel leaves (dE:874–914, 554–577,
##     634–661):
##      - every next-duel gift spent (the world's and the dice's), as after
##        any duel;
##      - THE LIFE POOL ([method pool_after], dE:896–906): rule 0x01 adds the
##        duel's change of life (end − start), rule 0x02 then sets it to 0;
##      - A ROOM WON: `cleared` — the room passed, "Defeated %s" in the
##        journal (`@LOGSTRINGS` 4, the creature with its article; it counts in
##        the record's won and lost and the creatures' page as a world
##        meeting's does). NO VICTORY LOGGED, no cards, no amulet, no reward,
##        no colour learning, no quest (dE:874–914 call none of them).
##      - A ROOM LOST: `thrown_out` — "Lost this card" for the stake
##        ([method CreatureMeeting.lose_stake], the copy staked), "Lost to %s"
##        in the journal, the visit over (rule 0x01, which every castle and
##        dungeon carries, WorldGenerator; c2 §0.1); in a castle the words
##        "You are unceremoniously booted from / the stronghold of the Mighty
##        Black Wizard!" (`@DUNGEON` 11/12, `dsummon.wav` the pane's). No
##        lose music, as played.
##      - THE CASTLE'S WIZARD BEATEN: `beaten` — [method CastleWin.beat] next
##        (the journal and the victory are its own); LOST: `left` — "Lost
##        this card", no journal line, no booted words (as played).
##      - A DRAW, a room's or the wizard's: `again` — the hero pushed back,
##        the creature stays, the stake kept, nothing written, the pool
##        untouched (1.3's wizard draw, dE:653–659; [ours: 1997 slip — a room
##        drawn counted as won, the owner's ruling g3 of 2026-10-27, the pool
##        untouched by the lead's reading g3b]). Stepping in again is a new
##        duel: a new stake ([method draw_stake]).
##      - A CONCEDED duel ("Exit duel") is a loss, as in part B.
##
## THE HERO'S LIFE ([method hero_life], dE:847–859, duel.c 2205–2226): a life
## for each mana link no wizard rules, the lives carried from the world, the
## world's lives gift and the run's LIFE POOL — so A DUNGEON CARRIES ITS
## LOSSES (rule 0x01: the pool takes each duel's change) and A CASTLE'S DUELS
## EACH START FRESH (its rules 0x03: 0x01 then 0x02 zeroes the pool — the
## owner's ruling a1 of 2026-10-27, as played): the links plus the dice's
## lives found since the last duel. No floor: 0 loses at once (part B). The
## dice's lives live only in the pool, never in the world's gift, so they
## count once (1997's guard, dE:847–850, by construction).
##
## FIXED [ours: 1997 slips — the owner's rulings of 2026-10-27]:
##  - THE WORLD'S NEXT-DUEL GIFTS are spent only by the duel that uses them
##    (d2, the owner's D-4): a lives gift brought inside counts in the first
##    duel (1997 wiped it unused, dE:847–850), a card or the first move as
##    in any duel, and a visit with no duel keeps them all ([DungeonDoors]).
##    The dice's own gift, the card, stays in the run record and dies with
##    it, as 1997's did on leaving.
##  - THE BAN IS FAIR (i2): the deck's least size is counted AFTER the
##    rules' ban, and made up with ALLOWED basic lands only (1997 counted the
##    whole deck in use, banned cards too, and padded with any basic —
##    duel.c 2327–2346 — so a mono-black deck in a "No black cards" dungeon
##    played its few other cards and Swamps that broke the rule).
##  - THE STAKE IS AN ALLOWED CARD (f2): drawn among the deck's non-basic
##    cards the rules allow (1997 ignored the ban, dE:839–846: a Sol Ring
##    lost in a "No artifacts" dungeon); none allowed, nothing is staked
##    (the lead's reading). The game-over test stays 1997's.
##  - "NO BLACK CARDS" BARS EVERY BLACK CARD (j2): any card with black among
##    its colours, gold ones too (1997 matched the colour exactly, `color ==
##    1 << colour`, dE:778, and let gold cards through — while a town
##    trading "Black cards" takes them). The colours are the card's own: a
##    land's are its basic land types' (a Swamp black, Badlands black and
##    red, as 1997's table and the trades read them); any other card's its
##    real colours — so BLACK LOTUS, colourless, STAYS ALLOWED (the lead's
##    reading of the owner's j2: 1997's table coloured the Lotus and
##    Celestial Prism with all five colours and each Mox with its mana's;
##    those are colourless cards, allowed in every dungeon of a colour).
##  - THE BAN IS PER DUEL (h2): nothing of it outlives the duel (1997
##    restored a padded deck from a copy taken after the marks and kept the
##    banned cards out of later duels, VL:2210–2213).
##  - A LOST ROOM ENDS THE VISIT whatever the record's rules say (the lead's
##    call e: every slot carries 0x01; the room turned to wall, dE:560, is
##    never seen — no wall here).
## A dice card the rules bar is left out of the duel — a guard: [DungeonBoard]'s
## dice never give one (the owner's k2; [method bars] is the one test).
##
## DESIGNED, NEVER USED (dead in 1997, dead here; c2 spec §15,
## docs/adventure-unused-1997-features.md):
##  - THE ROOM CREATURES' DOUBLE WEIGHT ON THE HERO'S LIFE (`g_ai_combat_
##    value_weights[0] = 16` for every slot but 4, dE:792–795): reset to 8
##    before the AI first reads it, in both builds (c1 spec headline 9) —
##    the lead's call AI-1: not reproduced. Switched on, room creatures would
##    race and burn the hero's face; a profile weight on the foe's life would
##    carry it ([AiProfile]).
##  - "ONE DECK FOR ALL DUELS" (rule 0x20, unused-features §26) and 1997's
##    `g_one_deck_mode`: no reader, and since the owner's ruling of
##    2026-10-28 ("the player can have multiple decks") no clue line
##    either ([method WorldClues.lines]): it stays dead. Switched on, the
##    cards drawn in one room would be gone in the next — a dungeon would
##    wear the deck down. To switch on: the run record keeps the cards drawn
##    and [method hero_deck] leaves them out.
##  - THE HERO MOVING FIRST against a creature that starts with a card in
##    play (unused-features §4): it would fire in every castle duel (a castle
##    always has its card in effect). To switch on: `first_player = 0` in
##    [method duel_config] when `start_in_play[1]` is not empty.
##  - THE CARD "PERMANENTLY" IN EFFECT (§29): in play from the start only.
##  - THE CREATURE'S STRENGTH (2 in a castle, dE:798) and its hand modifier
##    0: they feed only the hand size, always seven (§2).
##  - "Defeated %1 (%2)" (`@LOGSTRINGS` 7, §31): never written.

## The duel's results, from the hero's side ([DuelReport]'s).
const WON := 1
const LOST := 0
const DRAWN := -1
## The castle's wizard's monster slot, and the room codes ([method slot_of]).
const WIZARD_SLOT := 4
const ROOM_FIRST := 3
const ROOM_LAST := 6
const WIZARD_ROOM := 15
## The castles' slots (0–4); 5–14 are the dungeons.
const CASTLES := 5
## The rules word's bits the duels read (the clue lines, [method
## WorldClues.lines]).
const CARRY := 0x01
const FRESH := 0x02
const NO_COLOR := 0x10
const ONE_DECK := 0x20
const NO_ARTIFACTS := 0x40
const NO_INSTANTS := 0x80
## What [method settle] tells the board.
const CLEARED := "cleared"
const AGAIN := "again"
const THROWN_OUT := "thrown_out"
const LEFT := "left"
const BEATEN := "beaten"
## No card left to stake ([method draw_stake] false): the adventure ends.
const GAME_OVER := "game_over"
## The sound as the creature is met (`Dngnduel.wav`, dE:809).
const SOUND := "sfx_dungeon_duel"
## The sound under the booted words (`dsummon.wav`, dE:698–712).
const BOOTED_SOUND := "sfx_dsummon"

## `@DUNGEON`, as 1997 words it (Advstrings.txt; 0-based): 15 a castle, 16 a
## dungeon — the creature with its article.
const ENCOUNTER_CASTLE := "Exploring the Castle...\nyou encounter %s!\n"
const ENCOUNTER_DUNGEON := "Exploring the Dungeon...\nyou encounter %s!\n"
## 17: `\n%1 has the spell %2!s!!\n` — the creature's name, then the minion
## (FormatMessage's numbered inserts; `!s!` the insert's type).
const HAS_SPELL := "\n%s has the spell %s!\n"
## 18 (as [constant LairDuels.STARTS_IN_PLAY], with 1997's line break).
const STARTS_IN_PLAY := "(%s starts in play!)\n"
## 19, over `losedul2.pic` (the pane's `lose_card`).
const LOST_CARD := "Lost this card"
## 11/12 (the same words for either gender of wizard): the castle's wizard.
const BOOTED := "You are unceremoniously booted from\nthe stronghold of the Mighty %s!\n"
## `@LOGSTRINGS` 4 and 5.
const DEFEATED := DuelSpoils.DEFEATED
const LOST_TO := DuelSpoils.LOST_TO


# ------------------------------------------------------------ the record --

## Field [param key] of the run record [param run] (a Dictionary or an
## object), [param fallback] when it has none.
static func read(run: Variant, key: String, fallback: Variant = null) -> Variant:
	var value: Variant = null
	if run is Dictionary:
		value = (run as Dictionary).get(key)
	elif run is Object and run != null:
		value = (run as Object).get(key)
	return fallback if value == null else value


## Field [param key] of the run record [param run] set to [param value].
static func write(run: Variant, key: String, value: Variant) -> void:
	if run is Dictionary:
		(run as Dictionary)[key] = value
	elif run is Object and run != null:
		(run as Object).set(key, value)


## The run's slot (0–14).
static func index_of(run: Variant) -> int:
	return int(read(run, "index", -1))


## The world's castle or dungeon slot of the run, `{}` for none.
static func world_slot(player: AdventurePlayer, run: Variant) -> Dictionary:
	var index := index_of(run)
	var world := player.world if player != null else null
	if world == null or index < 0 or index >= world.encounters.size():
		return {}
	return world.encounters[index]


## The run's colour (1 black … 5 white): the record's, else the world
## slot's (a castle's is its index + 1).
static func color_of(player: AdventurePlayer, run: Variant) -> int:
	var color := int(read(run, "color", 0))
	if color < 1 or color > 5:
		color = int(world_slot(player, run).get("color", 0))
	if (color < 1 or color > 5) and index_of(run) >= 0 and index_of(run) < CASTLES:
		color = index_of(run) + 1
	return clampi(color, 1, 5)


## The run's rules word: the record's, else the world slot's.
static func rules_of(player: AdventurePlayer, run: Variant) -> int:
	var rules: Variant = read(run, "rules")
	if rules == null:
		rules = world_slot(player, run).get("rules", 0)
	return int(rules)


## Whether the run is a wizard's castle.
static func is_castle(run: Variant) -> bool:
	return bool(read(run, "castle", index_of(run) >= 0 and index_of(run) < CASTLES))


## The [CreatureBook] row in monster slot [param slot] of run [param run]
## (its `monsters`, any array of five rows), 0 for none.
static func monster_row(run: Variant, slot: int) -> int:
	var monsters: Variant = read(run, "monsters", [])
	var listed := typeof(monsters) in [TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_BYTE_ARRAY]
	if not listed or slot < 0 or slot >= int(monsters.size()):
		return 0
	return int(monsters[slot])


## The monster slot a room's event code names: 3–6 the creatures 0–3, 15
## the castle's wizard (4); −1 for no duel.
static func slot_of(code: int) -> int:
	if code >= ROOM_FIRST and code <= ROOM_LAST:
		return code - ROOM_FIRST
	return WIZARD_SLOT if code == WIZARD_ROOM else -1


# -------------------------------------------------------------- the setup --

## THE DUEL ABOUT TO BE FOUGHT against monster slot [param slot] (0–3 a
## room's creature, 4 the castle's wizard) of run [param run] — no dice
## drawn (the class doc, step 1): `{index, castle, color, rules, slot,
## final, row, minion, effect, words, hero_ante, hero_ante_at, no_ante}` —
## `final` the castle's wizard, `row` the creature ([CreatureBook]),
## `minion` and `effect` the cards it starts with in play ("" none), `words`
## the lines said. `{}` when the slot holds no creature. A new set-up for each
## duel; [method draw_stake] starts it.
static func setup(player: AdventurePlayer, run: Variant, slot: int) -> Dictionary:
	if player == null or slot < 0 or slot > WIZARD_SLOT:
		return {}
	var castle := is_castle(run)
	var color := color_of(player, run)
	var row := monster_row(run, slot)
	var final := castle and slot == WIZARD_SLOT
	# The castle's wizard is the colour's tier-20 row (dE:338–342); a record
	# that lost it still meets him.
	if final and CreatureBook.kind(row) != CreatureBook.CASTLE_WIZARD:
		row = CreatureBook.castle_row(color)
	if row < 1 or row > 54:
		return {}
	var effect_id: Variant = read(run, "card_in_effect")
	if effect_id == null:
		effect_id = world_slot(player, run).get("card_in_effect", -1)
	var out := {"index": index_of(run), "castle": castle, "color": color,
		"rules": rules_of(player, run), "slot": slot, "final": final, "row": row,
		"minion": minion(castle, color, slot, player.difficulty),
		"effect": String(WorldClues.EFFECT_CARDS.get(int(effect_id), "")),
		"hero_ante": [] as Array[String], "hero_ante_at": [] as Array[int], "no_ante": false}
	out["words"] = words(out)
	return out


## THE DUEL OF THE ROOM THE HERO STEPS INTO: [method setup] for the
## creature the run's `code` names ([method slot_of]); `{}` for none.
static func setup_room(player: AdventurePlayer, run: Variant) -> Dictionary:
	return setup(player, run, slot_of(int(read(run, "code", 0))))


## THE CASTLE'S MINION (dE:796–806; retail Palette.c 7417–7425): in a
## castle, for monster slot [param slot] at [param difficulty], `n = slot +
## difficulty − 3`; from 0, colour [param color]'s minion `clamp(n, 0, 2)`
## ([constant CreatureBook.MINIONS]) — the castle's wizard has one on every
## level, the first room's creature only on Wizard. A dungeon never has one
## (1997 never computes it there). "" for none.
static func minion(castle: bool, color: int, slot: int, difficulty: int) -> String:
	if not castle:
		return ""
	var n := slot + clampi(difficulty, 0, 3) - 3
	if n < 0:
		return ""
	var three: Array = CreatureBook.MINIONS.get(clampi(color, 1, 5), [])
	return String(three[clampi(n, 0, 2)]) if three.size() == 3 else ""


## THE WORDS as the creature is met (`@DUNGEON` 15/16, 17, 18), a line each
## as 1997 broke them — the blank line before the minion's is 1997's.
static func words(duel: Dictionary) -> Array[String]:
	var row := int(duel.get("row", 0))
	var text := (ENCOUNTER_CASTLE if bool(duel.get("castle", false)) else ENCOUNTER_DUNGEON) \
		% CreatureBook.called(row)
	if String(duel.get("minion", "")) != "":
		text += HAS_SPELL % [CreatureBook.name_of(row), String(duel["minion"])]
	if String(duel.get("effect", "")) != "":
		text += STARTS_IN_PLAY % String(duel["effect"])
	return CreatureMeeting.lines_of(text)


# ---------------------------------------------------------------- the ban --

## WHETHER THE RULES [param rules] OF A SLOT OF COLOUR [param color] BAR
## CARD [param card_name] from the hero's deck (dE:756–783): 0x80 an instant
## (1997's instants and interrupts: the engine's instants), 0x40 an artifact
## (artifact creatures too), 0x10 a card with the slot's colour among its own
## [ours: 1997 slip j — any colour, gold cards too; the colours the card's
## own, a land's by its land types — the class doc]. 0x01, 0x02 and 0x20 bar
## nothing. A card the game does not know is never barred.
static func bars(card_name: String, rules: int, color: int) -> bool:
	if rules & (NO_COLOR | NO_ARTIFACTS | NO_INSTANTS) == 0 or not CardRegistry.has_card(card_name):
		return false
	var data := CardRegistry.get_card(card_name)
	if rules & NO_INSTANTS != 0 and data.is_type(Mtg.CardType.INSTANT):
		return true
	if rules & NO_ARTIFACTS != 0 and data.is_type(Mtg.CardType.ARTIFACT):
		return true
	if rules & NO_COLOR != 0 and color >= 1 and color <= 5:
		return colors_of(data) & (1 << color) != 0
	return false


## A card's colours as 1997 bits (0x02 black … 0x20 white, 0x01 none): a
## land's by its basic land types ([method CardValue.land_colors]), any
## other card's own ([method CardValue.color_bits]) — never the 1997 table's
## colouring of colourless artifacts (the class doc).
static func colors_of(data: CardData) -> int:
	if data.is_land():
		return CardValue.land_colors(data)
	return CardValue.color_bits(data.color_mask())


## THE CARDS OF THE DECK IN USE THAT [param duel]'s RULES BAR (`rules`,
## `color`: a set-up of [method setup], or the run record itself), one entry
## per copy, in the bag's order.
static func forbidden(player: AdventurePlayer, duel: Variant) -> Array[String]:
	var out: Array[String] = []
	var rules := int(read(duel, "rules", 0))
	var color := int(read(duel, "color", 0))
	for card_name in player.deck_cards():
		if bars(card_name, rules, color):
			out.append(card_name)
	return out


## THE HERO'S DECK FOR THIS DUEL ([param duel]'s rules): the deck in use less
## the cards barred ([method bars]), padded with random basic lands — each
## `rand(5)` of [constant CreatureDeck.BASICS] on the adventure's dice
## (duel.c 2340–2346), drawn again while the rules bar it — to the
## difficulty's least ([constant CreatureMeeting.DECK_LEAST], the stake
## counted) [ours: 1997 slip i — the least counted after the ban, allowed
## basics only]. Kept in [param duel] for the duel (`deck`): asked again, the
## same deck, the dice drawn once.
static func hero_deck(player: AdventurePlayer, duel: Dictionary) -> Array:
	if duel.has("deck"):
		return (duel["deck"] as Array).duplicate()
	var rules := int(duel.get("rules", 0))
	var color := int(duel.get("color", 0))
	var out: Array = []
	for card_name in player.deck_cards():
		if not bars(card_name, rules, color):
			out.append(card_name)
	var allowed: Array[String] = []
	for basic in CreatureDeck.BASICS:
		if not bars(basic, rules, color):
			allowed.append(basic)
	var least: int = CreatureMeeting.DECK_LEAST[clampi(player.difficulty, 0, 3)]
	if out.size() < least and not allowed.is_empty():
		var dice := MsvcRandom.new(player.dice)
		while out.size() < least:
			var basic: String = CreatureDeck.BASICS[dice.below(CreatureDeck.BASICS.size())]
			if basic in allowed:
				out.append(basic)
		player.dice = dice.state
	duel["deck"] = out
	return out.duplicate()


# ------------------------------------------------------------- the stake --

## THE HERO'S STAKE DRAWN for the duel of [param duel] — and a new duel
## begun on it (a draw's second try stakes anew): `rand(500)` over the bag
## until a card of the deck in use, no basic land, the rules allow (the
## class doc) — into `hero_ante` / `hero_ante_at`, as the meeting's
## ([method CreatureMeeting.lose_stake] reads them). False — and `no_ante` —
## when the deck in use holds no card to stake at all, banned or not: THE
## GAME IS OVER (`ExitIfNoUsableDeckCards`, dE:838; the board told
## [constant GAME_OVER], the world's end screen with [constant
## CreatureMeeting.NO_ANTE]). With cards to stake but none
## allowed, nothing is staked [ours: 1997 slip f — the lead's reading].
static func draw_stake(player: AdventurePlayer, duel: Dictionary) -> bool:
	duel.erase("settled")
	duel.erase("deck")
	duel["hero_ante"] = [] as Array[String]
	duel["hero_ante_at"] = [] as Array[int]
	duel["no_ante"] = false
	var usable := CreatureMeeting.usable_cards(player)
	if usable.is_empty():
		duel["no_ante"] = true
		return false
	var rules := int(duel.get("rules", 0))
	var color := int(duel.get("color", 0))
	var allowed := {}
	for at in usable:
		if not bars(String(player.cards[at]["card"]), rules, color):
			allowed[at] = true
	if allowed.is_empty():
		return true
	var dice := MsvcRandom.new(player.dice)
	var bag := maxi(AdventurePlayer.BAG_MOST, player.cards.size())
	# 1997's draw ([method MsvcRandom.place_among]: never endless past
	# 32,767 cards, the 0.50.65 bug campaign, k1-3).
	var places: Array[int] = []
	places.assign(allowed.keys())
	var at := dice.place_among(bag, places)
	(duel["hero_ante"] as Array[String]).append(String(player.cards[at]["card"]))
	(duel["hero_ante_at"] as Array[int]).append(at)
	player.dice = dice.state
	return true


# ------------------------------------------------------------- the lives --

## THE HERO'S LIFE IN THE NEXT DUEL OF RUN [param run], by its parts:
## `{base, links, carried, gift, pool, total}` — the life before the links
## (0, or under the Embark's "Base 10 + links" 10 and the World Magics'
## bonuses, [method AdventurePlayer.life_base]; since 0.50.65), the mana
## links, the world's lives carried, the world's lives gift (d2: it counts
## here), the run's life pool (the dice's lives and, in a dungeon, every
## duel's change — counted from the duel's start, so it starts from the
## base too). The board's "life you carry" is `total`.
static func life_parts(player: AdventurePlayer, run: Variant) -> Dictionary:
	var out := {"base": player.life_base(), "links": player.mana_links(),
		"carried": player.next_duel_life_carried, "gift": player.next_duel_life,
		"pool": int(read(run, "life_pool", 0))}
	out["total"] = int(out["base"]) + int(out["links"]) + int(out["carried"]) + int(out["gift"]) \
		+ int(out["pool"])
	return out


## THE HERO'S LIFE IN THE DUEL ([method life_parts]' total; no floor).
static func hero_life(player: AdventurePlayer, run: Variant) -> int:
	return int(life_parts(player, run)["total"])


## THE CREATURE'S LIFE ([method CreatureBook.duel_life]) at the hero's
## difficulty: a henchman's with the hero's World Magics, the castle's
## wizard's with the wins over his colour and the towns he rules (as
## [method WiseMan.castle_life]).
static func creature_life(player: AdventurePlayer, duel: Dictionary) -> int:
	var color := clampi(int(duel.get("color", 1)), 1, 5)
	var towns: Array[int] = WorldStatus.taps(player)
	return CreatureBook.duel_life(int(duel.get("row", 0)), player.difficulty,
		{"world_magics": player.world_magics, "wins": player.wins_over_color(color),
			"towns": towns[color - 1]})


## THE LIFE POOL AFTER A DUEL under [param rules] (dE:896–906): 0x01 adds
## the duel's change, [param end] − [param start]; 0x02 then sets it to 0
## (a castle's: every duel there starts fresh — the owner's ruling a1).
static func pool_after(rules: int, pool: int, start: int, end: int) -> int:
	var out := pool
	if rules & CARRY != 0:
		out += end - start
	if rules & FRESH != 0:
		out = 0
	return out


# --------------------------------------------------------------- the duel --

## THE DUEL HANDED TO THE ENGINE for [param duel] in run [param run] (the
## class doc, step 3) — after [method draw_stake]. Built whole: the meeting's
## [method CreatureMeeting.duel_config] would pad the unbanned deck on the
## dice first.
static func duel_config(player: AdventurePlayer, run: Variant, duel: Dictionary) -> DuelConfig:
	var row := int(duel.get("row", 0))
	var config := DuelConfig.new()
	var deck := hero_deck(player, duel)
	var stake: Array = duel.get("hero_ante", [])
	for card_name in stake:
		# The stake comes out of the duel's library (an allowed card); a
		# record whose stake the deck lacks makes it into the ante instead.
		if String(card_name) in deck:
			(config.ante_cards[0] as Array).append(String(card_name))
		else:
			(config.ante_extras[0] as Array).append(String(card_name))
	config.decks = [deck, CreatureDeck.for_meeting(row, 0)]
	config.player_names = [player.name if player.name != "" else "Hero", CreatureBook.duel_name(row)]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [deck_name if deck_name != "" else "Deck %d" % (player.current_deck + 1),
		CreatureBook.name_of(row)]
	config.portraits = [player.portrait, CreatureBook.face_id(row)]
	config.lives = [hero_life(player, run), creature_life(player, duel)]
	config.pilots = [null, CreatureMeeting.ai_for(player.difficulty)]
	if player.next_duel_first_move:
		config.first_player = 0
	var hero_cards: Array = []
	if player.next_duel_card != "":
		hero_cards.append(player.next_duel_card)
	var dice_card := String(read(run, "dice_card", ""))
	if dice_card != "" and not bars(dice_card, int(duel.get("rules", 0)), int(duel.get("color", 0))):
		hero_cards.append(dice_card)
	var creature_cards: Array = []
	for card_name in [String(duel.get("minion", "")), String(duel.get("effect", ""))]:
		if card_name != "":
			creature_cards.append(card_name)
	config.start_in_play = [hero_cards, creature_cards]
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.ai_random_play_or_draw = true
	config.pace = Settings.ai_pace()
	config.rng_seed = randi() | 1
	config.apply_deck_colors()
	CreatureMeeting.hero_playmat(config, player)
	return config


# ---------------------------------------------------------------- the end --

## THE DUEL OF [param duel] SETTLED from [param report] ([param conceded]:
## "Exit duel" taken — a loss), the run [param run] told (the class doc,
## step 4): `{result, outcome, final, row, name, lost, journal, booted,
## pool, lives_start, lives_end}` — `outcome` one of [constant CLEARED],
## [constant AGAIN], [constant THROWN_OUT], [constant LEFT], [constant
## BEATEN]; `lost` the cards lost ("Lost this card" each); `booted` the
## castle's words after a room lost. Once a duel: asked again, the same.
static func settle(player: AdventurePlayer, run: Variant, duel: Dictionary, report: DuelReport,
		conceded := false) -> Dictionary:
	if duel.has("settled"):
		return duel["settled"]
	var result := LairDuels.result_of(report, conceded)
	var row := int(duel.get("row", 0))
	var final := bool(duel.get("final", false))
	var castle := bool(duel.get("castle", false))
	var start := report.lives_start[0] if report != null else 0
	var end := report.lives_end[0] if report != null else start
	var out := {"result": result, "outcome": "", "final": final, "row": row,
		"name": CreatureBook.name_of(row), "lost": [] as Array[String], "journal": "",
		"booted": [] as Array[String], "lives_start": start, "lives_end": end}
	player.clear_duel_gifts()
	write(run, "dice_card", "")
	if result != DRAWN:
		write(run, "life_pool", pool_after(int(duel.get("rules", 0)), int(read(run, "life_pool", 0)), start, end))
	match result:
		WON:
			out["outcome"] = BEATEN if final else CLEARED
			if not final:
				out["journal"] = DEFEATED % CreatureBook.called(row)
				player.log_event("duel", out["journal"], {"won": true, "creature": CreatureBook.name_of(row),
					"row": row, "color": int(duel.get("color", 0)), "dungeon": int(duel.get("index", -1))})
		LOST:
			out["outcome"] = LEFT if final else THROWN_OUT
			out["lost"] = CreatureMeeting.lose_stake(player, duel)
			if not final:
				out["journal"] = LOST_TO % CreatureBook.called(row)
				player.log_event("duel", out["journal"], {"won": false, "creature": CreatureBook.name_of(row),
					"row": row, "color": int(duel.get("color", 0)), "dungeon": int(duel.get("index", -1))})
				if castle:
					out["booted"] = booted_words(int(duel.get("color", 1)))
		_:
			out["outcome"] = AGAIN
	out["pool"] = int(read(run, "life_pool", 0))
	duel["settled"] = out
	return out


## The castle's words after a room lost (`@DUNGEON` 11/12): the wizard of
## colour [param color], a line each.
static func booted_words(color: int) -> Array[String]:
	return CreatureMeeting.lines_of(BOOTED % WorldNames.WIZARDS[clampi(color, 1, 5) - 1])


## Whether [param outcome] ends the visit: a room lost, the wizard lost or
## beaten (the board then leaves through [method DungeonDoors.leave], or —
## beaten — through [method CastleWin.beat] first).
static func ends_visit(outcome: String) -> bool:
	return outcome == THROWN_OUT or outcome == LEFT or outcome == BEATEN
