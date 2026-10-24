class_name CreatureMeeting
extends RefCounted
## A CREATURE MET ON THE MAP — 1.3's `RunWorldLairMonsterEncounter` up to
## the duel (world_lair_monster_encounter.c 1540–2257; retail town.c
## ~1400–1700 the same but where marked), headless: what the meeting is, what
## the creature says and offers, what each choice does, and the duel it
## hands to the engine ([method duel_config]). The pane is
## [EncounterPane]; what a duel leaves is [DuelSpoils]; the world's door is
## [WorldEncounters].
##
## THE MEETING RECORD ([method begin], [method meet]) — a Dictionary, as a
## lair's event is ([LairEvent]):
##  - `slot` the roaming slot met (7 the besieger, −1 none: a caller's own
##    creature), `row` the creature fought ([CreatureBook]; a summons
##    changes it), `met_row` the one met, `color` its colour (1 black …
##    5 white: the slot's, the land it was spawned on), `kind`, `relation`
##    (0 none, 1 near its wizard's stronghold, 2 the siege creature),
##    `wins` (the hero's wins over its kind on its colour), `strength` (S),
##    `base_strength` (the met creature's table strength: a summons keeps
##    it), `bribe` (10·S), `quest` (the quest's creature).
##  - THE ANTES: `hero_ante` (names) and `hero_ante_at` (their places in
##    [member AdventurePlayer.cards]) — a non-basic card of the deck in use,
##    every copy alike (`internal_rand(500)` over the bag until a slot of
##    the deck in use, not a basic land, E:1600–1611); `creature_ante`
##    (names: [method CreatureDeck.ante_draw], E:1576–1590; henchmen stake
##    nothing). `no_ante` true when the deck in use holds no card to stake:
##    THE GAME IS OVER ("You have no power for even an Ante!", `@QUESTFAILED`
##    0, 1, 4, 5 — `ExitIfNoUsableDeckCards`, visitLocation.c 2252). The
##    pane says so; the end screen itself is the adventure's end's
##    ([WorldEncounters] GAME_OVER).
##  - `sleight_used` (the ante changed once with Sleight of Hand).
##  - after [method prepare_duel]: `total_wins`, `modifier` (the hand
##    modifier), `filter` (the creature's colour sections), `special`,
##    `events` (the lines said), `swap_row` ("Try this deck": the hero plays
##    that row's deck), `summoned` (the row a summons brought), `card` (the
##    creature's card in play), `first_strike`, `mind_control`.
##
## WHAT THE CREATURE OFFERS ([method options], E:1714–1863), by relation
## and wins: near its stronghold or besieging a town only Duel; with fewer
## than 5 wins over its kind on its colour Duel, Pay (10·S gold, with gold
## enough), Answer a riddle (from 2·(difficulty + 1) wins: 2–4 at
## Apprentice, 4 at Magician, never above); from 5 wins Accept tribute;
## with Sleight of Hand, once a meeting and a one-card ante, Change ante
## card. A henchman (kind 11) only says its wizard sent it: Duel. There is
## no flight: 1997 asked again on Escape (E:1856–1863).
##
## AFTER THE CHOICE: Pay ([method pay]) and a riddle ([method riddle],
## [method riddle_answered]) end the meeting — a wrong answer loses the
## hero's ante; a tribute ([method tribute], [method take_payment],
## [method spell_choices] / [method take_spell], [method magic_choices] /
## [method reveal_magic], [method secrets]) ends it too, or "Duel Anyway";
## Duel goes to [method prepare_duel] — the special meeting
## (`(monster_timer >> 2) % 3 == 0`, `dsummon.wav`) and its events — then
## [method duel_config].
##
## FIXED [ours: 1997 slips, each marked where it is fixed; the lead's
## defaults under the owner's ruling 1]:
##  - the bribe is offered whatever deck slot the hero's ante came from
##    (1997 also tested `deck_or_card_index != 0`, a vestige: an ante drawn
##    from the bag's first slot hid the bribe; retail the same);
##  - tribute jewels are of the colour the words name, the creature's (1.3
##    named the creature's colour and paid a colour drawn, `rand(5) + 1`;
##    the draw is still made);
##  - "Accept tribute" from the quest's creature reads "Duel this %s" (1997
##    showed "Accept tribute" and then silently duelled, E:1869);
##  - the henchmen's hand modifier is 0 (1997 read a World Magic's price at
##    a stale or −1 index, E:2138–2140);
##  - Mind Control only on the meetings that announce it (1997's duel copied
##    the hero's deck whenever `monster_timer % 3 == 0`, duel.c 2483, and
##    the meeting announced it only when also special: a silent Mind
##    Control one meeting in six);
##  - the creature's colour filter is not overwritten by "Try this deck" or
##    a summons (1997 reused its variable for the row drawn, so the
##    creature's sections came from the row number read as colour bits,
##    E:2153, 2180, 2245);
##  - the creature's ante comes out of its library under "Try this deck"
##    too (1997 lifted it only when the hero played their own deck,
##    duel.c 2385–2391: the creature played the card it staked);
##  - the besieger's words name the town it besieges (1997 the town nearest
##    it; the lead's ruling: the besieged town is the one meant);
##  - the hero's deck colours are read from the deck in use at the meeting
##    (1997 read `g_deck_color_bitmap` as last computed by a shop's or a
##    reward's copy count: usually the same deck, sometimes a stale one);
##  - three stakes (a castle wizard's, kind 12) are three different cards
##    (1997 drew each from the whole bag and could stake one card twice).
##
## DESIGNED, NEVER USED (dead in 1997, dead here; each in
## `docs/adventure-unused-1997-features.md`, §1–4 and §10, with what it
## would change and how to switch it on):
##  - THE HERO'S LIFE BASE 10 AND THE WORLD MAGICS' BONUSES (§1): duel.c
##    2205–2226 starts at 10, +2 Haggler's Coin, +3 Ring of the Guardian, +5
##    Fruit of Sustenance — then sets the life again from the links. Here
##    [method hero_life] would add [constant LIFE_BASE] and
##    [constant LIFE_BONUSES]; they are kept as data only.
##  - HAND SIZES BY STRENGTH (§2) and THE FIRST MOVE BY DIFFICULTY (§3):
##    computed in `play_duel` and overwritten (seven cards, a fair coin) —
##    [DuelOpening]'s doc; [method duel_config] keeps the meeting's
##    `modifier`, their input, and passes seven and the toss.
##  - THE HERO MOVING FIRST AGAINST A CREATURE THAT STARTS WITH A CARD (§4):
##    duel.c 2502–2511 marks it after the first player is decided; here it
##    would be `first_player = 0` in [method duel_config] when `card` is set.
##  - THE "%s ANTE" CAPTION (§10): PRE[2] formatted and overwritten; the
##    plaques read "Opponent Ante" and "Your Ante" ([constant ANTE_WORDS]).
##  - A BRIBE IN AMULETS: `@ENCOUNTER_PREDUEL` 14, " Pay 1 %s." — a choice
##    worded for one jewel (the jewels' names are its neighbours, 24–33) —
##    stands in the string table between the gold bribe (13) and the riddle
##    (15), and no line of 1.3 reads it (every other index of the table is
##    read, E:1612–2224) [new — for the unused-features page]. Switched on,
##    a creature could be paid off with an amulet of its colour instead of
##    10·S gold: amulets, which power the World Magics and buy cards from
##    the towns' traders, would become a way past a creature, and a hero poor
##    in gold but rich in jewels could travel unfought. To switch it on: an
##    option `pay_amulet` in [method options] (relation 0, fewer than five
##    wins, an amulet of the creature's colour held), worded
##    [constant PAY_AMULET] with [constant JEWEL], taking the amulet in a
##    `pay_amulet` like [method pay].

## The meeting's relations (`encounter_relation_type`, E:1714–1732).
const NONE := 0
const STRONGHOLD := 1
const SIEGE := 2
## The besieger's slot ([constant WorldMagic.SIEGE_SLOT]).
const SIEGE_SLOT := 7
## Wins over a kind on a colour from which its creatures pay tribute.
const TRIBUTE_WINS := 5
## The deck in use's least size by difficulty, counted with the ante
## (duel.c 2327–2349, retail Kimpic.c 19680–19684; the manual's 25/30/35/40
## is not what the code does): padded with random basic lands for the duel.
const DECK_LEAST: Array[int] = [30, 35, 40, 40]
## The hero's opening hand and the creature's: always seven (the strength
## formula is dead, see the class doc).
const HAND := 7
## DESIGNED, NEVER USED: the hero's life before the links, and the World
## Magics that would have added to it (duel.c 2205–2216).
const LIFE_BASE := 10
const LIFE_BONUSES := {"Haggler's Coin": 2, "Ring of the Guardian": 3, "Fruit of Sustenance": 5}
## Sleight of Hand, the World Magic that changes the ante (bit 0).
const SLEIGHT := "Sleight of Hand"

## `@ENCOUNTER_PREDUEL`, as 1997 words it (Advstrings.txt; 0-based):
## 0, 1 the plaques; 2 the dead caption.
const ANTE_WORDS: Array[String] = ["Opponent Ante", "Your Ante", "%s ANTE"]
## 3/4 near the stronghold, 5/6 the siege, 7/8 the domain, 9/10 the tribute
## (each pair alike: the wizard's gender chose between identical words).
const NEAR_STRONGHOLD := "Those who near the stronghold\nof the Mighty %s\nwill be met with the firmest resistance.\nYou must..."
const CHALLENGE := "Those who would challenge the\nGreat %s for\nSupremacy of %s must..."
const DOMAIN := "Those who enter the domain\nof the Mighty %s\nmust pay for the privilege.\nWill you..."
const TREMBLE := "The %s who inhabit the\ndomain of the Mighty %s\ntremble in fear of your visage.\nWill you..."
## 41/42 a henchman, by its wizard's gender.
const HENCHMAN_WORDS := "The Evil %s\nhas sent %s\nmost trusted servant to\ntest your strength.\nYou must..."
## The choices: 11 Duel, 12 Accept tribute, 13 Pay, 15 Answer, 16 Change.
const DUEL := "Duel this %s."
const ACCEPT_TRIBUTE := "Accept tribute for your mercy?"
const PAY := "Pay %d gold."
## DESIGNED, NEVER USED: 14, a bribe of one jewel (see the class doc).
const PAY_AMULET := "Pay 1 %s."
const ANSWER := "Answer a riddle."
const CHANGE_ANTE := "Change ante card."
## The tribute: 17 the thanks; 18–20 the offers; 21–23 the payments;
## 24–28 and 29–33 the jewels, one and many; 34 Duel Anyway; 35 the spell's
## pick; 36–39 the World Magic and the castle's answers.
const THANKS := "I thank you for your mercy granted.\nWould you like..."
const OFFERS: Array[String] = ["A spell from my deck?", "The location of WORLDMAGIC cards?",
	"Secrets from the %s?"]
const GOLD_PAID := "%d Gold"
const FOOD_PAID := "40 Food"
const JEWELS_PAID := "%d %s"
const JEWEL: Array[String] = ["black jewel", "blue jewel", "green jewel", "red jewel", "white jewel"]
const JEWELS: Array[String] = ["black jewels", "blue jewels", "green jewels", "red jewels", "white jewels"]
const DUEL_ANYWAY := "Duel Anyway"
const PICK_SPELL := "Pick a spell"
const WHICH_MAGIC := "Which WM spell do you seek..."
const ALL_MAGICS := "You have already gathered all of the\nWORLDMAGIC SPELLS!"
const MAGIC_FOUND := "%s may be\nfound in %s."
const DESTROYED := "You have already destroyed the %s"
## 40 the riddle missed.
const LOST_CARD := "Lost this card"
## 43–47 the special meeting's events.
const TRY_DECK := "Why don't you try this deck!"
const SUMMONS := "%s summons %s!"
const MIND_CONTROL := "%s has Mind Control!"
const FIRST_STRIKE := "%s has First Strike!"
const HAS_CARD := "%s has card: %s!"
## `@QUESTFAILED` 0, 1, 4, 5: the game over with nothing to stake.
const NO_ANTE: Array[String] = ["You have no power for even an Ante!",
	"Your Righteous Quest has Failed",
	"The Evil Planeswalker Arzakon\nand his Gruesome Minions\nhave worn you down",
	"The people will suffer\na thousand more years of their oppression\nbefore another Savior shall rise up from amongst them\nto challenge the great Arzakon and his Slimy Minions"]
## The food a tribute gives.
const TRIBUTE_FOOD := 40


# ------------------------------------------------------------ the meeting --

## THE MEETING WITH THE CREATURE OF ROAMING SLOT [param slot]
## ([member AdventurePlayer.monsters]: `creature` its row, `color`, `x`, `y`,
## the besieger's `town`) — [method meet]; `{}` when the slot holds no
## creature.
static func begin(player: AdventurePlayer, slot: int) -> Dictionary:
	var held := {}
	for entry in player.monsters:
		if entry is Dictionary and int((entry as Dictionary).get("slot", -1)) == slot:
			held = entry
	var row := int(held.get("creature", 0))
	if String(held.get("kind", "")) != "creature" or row < 1 or row > 54:
		return {}
	var at := Vector2i(int(held.get("x", player.position.x)), int(held.get("y", player.position.y)))
	var meeting := meet(player, row, clampi(int(held.get("color", 1)), 1, 5), slot, at)
	if held.has("town"):
		meeting["town"] = int(held["town"])
	return meeting


## A MEETING WITH CREATURE [param row] OF COLOUR [param color] (1 black …
## 5 white), met in roaming slot [param slot] (−1 none) where it stands at
## [param at] (world units; the hero's place when not given): the meeting
## record (see the class doc), its antes drawn on the adventure's dice — the
## creature's first, then the game's end tested, then the hero's, as 1997
## drew them (E:1576–1611). A lair's duel, a ruled town's or the besieger's
## build theirs here too.
static func meet(player: AdventurePlayer, row: int, color: int, slot := -1,
		at := Vector2i(-1, -1)) -> Dictionary:
	var where := at if at.x >= 0 else player.position
	var kind := CreatureBook.kind(row)
	var strength := CreatureBook.strength(row)
	var meeting := {"slot": slot, "row": row, "met_row": row, "color": color, "kind": kind,
		"at": where, "relation": NONE, "wins": 0, "strength": strength,
		"base_strength": CreatureBook.base_strength(row), "bribe": CreatureBook.bribe(row),
		"quest": int(player.quest.get("type", 0)) == -row and row > 0,
		"hero_ante": [] as Array[String], "hero_ante_at": [] as Array[int],
		"creature_ante": [] as Array[String], "no_ante": false, "sleight_used": false,
		"timer": player.monster_timer, "prepared": false}
	var dice := MsvcRandom.new(player.dice)
	var stake := CreatureDeck.ante_draw(row, dice)
	if stake != "":
		(meeting["creature_ante"] as Array[String]).append(stake)
	player.dice = dice.state
	if usable_cards(player).is_empty():
		meeting["no_ante"] = true
		return meeting
	_draw_hero_ante(player, meeting, 3 if kind == CreatureBook.CASTLE_WIZARD else 1)
	if kind != CreatureBook.HENCHMAN:
		meeting["relation"] = relation_of(player, row, color, slot, where)
		meeting["wins"] = player.wins_against(kind, color)
	return meeting


## THE RELATION (E:1714–1732): [constant SIEGE] for the besieger's slot;
## [constant STRONGHOLD] when the creature stands within `difficulty / 2 +
## 2` tiles, on both axes, of its colour's castle (castle slot colour − 1);
## else [constant NONE].
static func relation_of(player: AdventurePlayer, _row: int, color: int, slot: int, at: Vector2i) -> int:
	if slot == SIEGE_SLOT:
		return SIEGE
	var world := player.world
	if world != null and color >= 1 and color - 1 < world.encounters.size():
		var castle: Dictionary = world.encounters[color - 1]
		var reach := player.difficulty / 2 + 2
		if absi(at.x / 32 - int(castle.get("x", -999))) <= reach \
				and absi(at.y / 32 - int(castle.get("y", -999))) <= reach:
			return STRONGHOLD
	return NONE


## The places in [member AdventurePlayer.cards] of the cards the hero may
## stake: the deck in use's, basic lands left out (`deck & 0x4000` clear,
## card id above 4 — `ExitIfNoUsableDeckCards`, visitLocation.c 2252).
static func usable_cards(player: AdventurePlayer) -> Array[int]:
	var out: Array[int] = []
	for i in player.cards.size():
		var entry := player.cards[i] as Dictionary
		if (entry.get("decks", []) as Array).has(player.current_deck) \
				and not String(entry.get("card", "")) in CreatureDeck.BASICS:
			out.append(i)
	return out


## The hero's stake drawn anew: [param count] cards, each `rand(500)` over
## the bag until a usable one (every copy alike), as 1997 drew it.
## [Ours: 1997 slip — three stakes drew from the whole bag each and could
## stake one card twice; a card already staked is drawn again here.]
static func _draw_hero_ante(player: AdventurePlayer, meeting: Dictionary, count: int) -> void:
	var usable := usable_cards(player)
	var names: Array[String] = []
	var places: Array[int] = []
	var dice := MsvcRandom.new(player.dice)
	var bag := maxi(AdventurePlayer.BAG_MOST, player.cards.size())
	for n in mini(count, usable.size()):
		while true:
			var at := dice.below(bag)
			if at in usable and not at in places:
				places.append(at)
				names.append(String(player.cards[at]["card"]))
				break
	player.dice = dice.state
	meeting["hero_ante"] = names
	meeting["hero_ante_at"] = places


# --------------------------------------------------------- what it says --

## THE CREATURE'S WORDS by its relation and the wins (E:1745–1797; a
## henchman's 2085–2112), a line each as 1997 broke them.
static func words(player: AdventurePlayer, meeting: Dictionary) -> Array[String]:
	var color := clampi(int(meeting["color"]), 1, 5)
	var wizard: String = WorldNames.WIZARDS[color - 1]
	var text := ""
	if int(meeting["kind"]) == CreatureBook.HENCHMAN:
		text = HENCHMAN_WORDS % [wizard, "her" if wizard_feminine(color) else "his"]
	else:
		match int(meeting["relation"]):
			STRONGHOLD:
				text = NEAR_STRONGHOLD % wizard
			SIEGE:
				text = CHALLENGE % [wizard, besieged_town(player, meeting)]
			_:
				if int(meeting["wins"]) < TRIBUTE_WINS:
					text = DOMAIN % wizard
				else:
					text = TREMBLE % [String(CreatureBook.ROWS[int(meeting["row"])][CreatureBook.PLURAL]), wizard]
	return lines_of(text)


## Whether colour [param color]'s wizard is a woman (`IsWizardColorFeminine`:
## the Blue and the Red Wizardess).
static func wizard_feminine(color: int) -> bool:
	return String(WorldNames.WIZARDS[clampi(color, 1, 5) - 1]).ends_with("ess")


## The town the besieger's words name: the one it besieges. [Ours: 1997
## slip — the town nearest the creature (`FindNearestTownIndex`, E:1765);
## the besieged town is the one meant.]
static func besieged_town(player: AdventurePlayer, meeting: Dictionary) -> String:
	var town := int(meeting.get("town", -1))
	var world := player.world
	if world == null:
		return ""
	if town < 0 or town >= world.sites.size():
		var at: Vector2i = meeting.get("at", player.position)
		town = WorldCreatures.nearest_site(world, Vector2i(at.x / 32, at.y / 32))
	return WorldNames.site_name(world, town)


## WHAT THE HERO MAY DO (E:1799–1853): `[id, words, ready]` each, in 1997's
## order — `duel`, `tribute`, `pay`, `riddle`, `change` (see the class doc).
static func options(player: AdventurePlayer, meeting: Dictionary) -> Array:
	var out: Array = []
	var name := CreatureBook.name_of(int(meeting["row"]))
	if int(meeting["kind"]) == CreatureBook.HENCHMAN:
		return [["duel", DUEL % name, true]]
	var relation := int(meeting["relation"])
	var wins := int(meeting["wins"])
	if relation == NONE and wins >= TRIBUTE_WINS:
		# [Ours: 1997 slip — the quest's creature showed "Accept tribute" and
		# duelled on the click (E:1869); it says what it does.]
		if bool(meeting["quest"]):
			out.append(["duel", DUEL % name, true])
		else:
			out.append(["tribute", ACCEPT_TRIBUTE, true])
	else:
		out.append(["duel", DUEL % name, true])
	# [Ours: 1997 slip — the bribe also needed the ante's deck slot ≠ 0.]
	if relation == NONE and wins < TRIBUTE_WINS and player.gold >= int(meeting["bribe"]) \
			and int(meeting["bribe"]) > 0:
		out.append(["pay", PAY % int(meeting["bribe"]), true])
	if relation == NONE and wins < TRIBUTE_WINS and wins >= (player.difficulty + 1) * 2:
		out.append(["riddle", ANSWER, true])
	if player.owns(SLEIGHT) and not bool(meeting["sleight_used"]) \
			and (meeting["hero_ante"] as Array).size() == 1:
		out.append(["change", CHANGE_ANTE, true])
	return out


# ------------------------------------------------------------ the choices --

## PAY THE BRIBE (E:2075–2083): 10·S gold, and the creature goes. False when
## the purse no longer holds it (it may have been spent since it was
## offered).
static func pay(player: AdventurePlayer, meeting: Dictionary) -> bool:
	var cost := int(meeting["bribe"])
	if cost <= 0 or player.gold < cost:
		return false
	player.gold -= cost
	return true


## CHANGE ANTE CARD with Sleight of Hand (E:2033–2047): the hero's stake
## drawn again by the same rule — it may be the same card — once a meeting.
## The new stake's name, "" when it may not be changed.
static func change_ante(player: AdventurePlayer, meeting: Dictionary) -> String:
	if bool(meeting["sleight_used"]) or not player.owns(SLEIGHT) \
			or (meeting["hero_ante"] as Array).size() != 1:
		return ""
	_draw_hero_ante(player, meeting, 1)
	meeting["sleight_used"] = true
	var names: Array = meeting["hero_ante"]
	return String(names[0]) if not names.is_empty() else ""


## THE RIDDLE (E:2049–2074; [CardRiddle], the lair's): made on the
## adventure's dice and kept in the meeting (`riddle`); `{}` when the card
## pool gives none.
static func riddle(player: AdventurePlayer, meeting: Dictionary) -> Dictionary:
	var dice := MsvcRandom.new(player.dice)
	var asked := CardRiddle.make(dice, player.difficulty)
	player.dice = dice.state
	meeting["riddle"] = asked
	return asked


## THE RIDDLE ANSWERED, [param right] or not (1997's `RunCardRiddleChallenge`
## counted Escape a wrong answer; ours waits for one — the pane's Escape does
## nothing at a riddle, [ours: 1997 slip]): right, the creature goes;
## wrong, the hero's stake is lost ("Lost this card", `loseduel.wav`). The
## cards lost.
static func riddle_answered(player: AdventurePlayer, meeting: Dictionary, right: bool) -> Array[String]:
	if right:
		return [] as Array[String]
	return lose_stake(player, meeting)


## THE HERO'S STAKE LOST (a riddle missed, a duel lost): each staked card
## out of the hero's cards. [Ours: 1997 slip — `RemoveCardFromDeckById`
## took the first copy of the card in the bag, which could be one outside
## the deck in use; the copy staked is the one lost here, found again by
## its name if the bag moved.] The names lost.
static func lose_stake(player: AdventurePlayer, meeting: Dictionary) -> Array[String]:
	var names: Array = meeting.get("hero_ante", [])
	var places: Array = meeting.get("hero_ante_at", [])
	var lost: Array[String] = []
	var take: Array[int] = []
	for n in names.size():
		var card_name := String(names[n])
		var at: int = int(places[n]) if n < places.size() else -1
		if at < 0 or at >= player.cards.size() or String(player.cards[at]["card"]) != card_name or at in take:
			at = _copy_of(player, card_name, take)
		if at >= 0:
			take.append(at)
			lost.append(card_name)
	take.sort()
	for i in range(take.size() - 1, -1, -1):
		player.cards.remove_at(take[i])
	meeting["hero_ante_at"] = [] as Array[int]
	return lost


## A copy of [param card_name] not in [param taken]: one in the deck in use
## first, else any; −1 for none.
static func _copy_of(player: AdventurePlayer, card_name: String, taken: Array[int]) -> int:
	var any := -1
	for i in player.cards.size():
		if i in taken or String(player.cards[i]["card"]) != card_name:
			continue
		if ((player.cards[i] as Dictionary).get("decks", []) as Array).has(player.current_deck):
			return i
		if any < 0:
			any = i
	return any


# ------------------------------------------------------------ the tribute --

## THE TRIBUTE OFFERED (E:1869–1922): what the creature offers (`offer`,
## `rand(3)`: 0 a spell from its deck, 1 the place of a World Magic, 2 its
## wizard's castle's secrets) and pays (`payment`, `rand(3)`: 0 `(tier +
## rand(10 − difficulty)) · 10` gold, 1 40 food, 2 `rand(3) + 1` jewels —
## amulets — of the creature's colour [ours: 1997 slip — 1.3 paid them in a
## colour drawn, `rand(5) + 1`, still drawn here]), kept in the meeting
## (`tribute`): `{offer, payment, gold, count, color, lines, choices}`,
## `choices` `[id, words, ready]` — `offer`, `payment`, `duel`.
static func tribute(player: AdventurePlayer, meeting: Dictionary) -> Dictionary:
	var dice := MsvcRandom.new(player.dice)
	var offer := dice.below(3)
	var payment := dice.below(3)
	var gold := 0
	var count := 0
	match payment:
		0:
			gold = (CreatureBook.tier(int(meeting["row"])) + dice.below(10 - clampi(player.difficulty, 0, 3))) * 10
		2:
			count = dice.below(3) + 1
			dice.below(5)   # 1.3's colour for the jewels, unused (see above)
	player.dice = dice.state
	var color := clampi(int(meeting["color"]), 1, 5)
	var offer_words: String = OFFERS[offer]
	if offer == 2:
		offer_words = offer_words % WorldNames.CASTLES[color - 1]
	var paid := ""
	match payment:
		0:
			paid = GOLD_PAID % gold
		1:
			paid = FOOD_PAID
		_:
			paid = JEWELS_PAID % [count, JEWEL[color - 1] if count == 1 else JEWELS[color - 1]]
	var out := {"offer": offer, "payment": payment, "gold": gold, "count": count, "color": color,
		"lines": lines_of(THANKS),
		"choices": [["offer", offer_words, true], ["payment", paid, true], ["duel", DUEL_ANYWAY, true]]}
	meeting["tribute"] = out
	return out


## THE TRIBUTE'S PAYMENT TAKEN (E:2010–2023): the gold, the food or the
## jewels. A line saying what was taken [ours: 1997 went back to the map
## without a word].
static func take_payment(player: AdventurePlayer, meeting: Dictionary) -> String:
	var paid: Dictionary = meeting.get("tribute", {})
	match int(paid.get("payment", -1)):
		0:
			player.gold += int(paid["gold"])
			return "You take %d gold." % int(paid["gold"])
		1:
			player.food += TRIBUTE_FOOD
			return "You take %d food." % TRIBUTE_FOOD
		2:
			var hue: String = AdventurePlayer.COLORS[clampi(int(paid["color"]), 1, 5) - 1]
			player.amulets[hue] = int(player.amulets.get(hue, 0)) + int(paid["count"])
			return "You take %d %s amulet%s." % [int(paid["count"]), hue, "" if int(paid["count"]) == 1 else "s"]
	return ""


## "A SPELL FROM MY DECK?" (E:1922–1946): the cards of the creature's own
## deck — its maindeck, the dungeons' treasures (`extra_ability` 0x100) left
## out — by name with their counts, for the hero to pick one.
static func spell_choices(meeting: Dictionary) -> Dictionary:
	var treasures := {}
	for treasure in ShandalarWorld.DUNGEON_CARDS:
		treasures[String(treasure[1])] = true
	var out := {}
	for card_name in CreatureDeck.for_meeting(int(meeting["row"]), 0):
		if not treasures.has(card_name):
			out[card_name] = int(out.get(card_name, 0)) + 1
	return out


## The spell picked from the creature's deck joins the hero's cards, in no
## deck ([method AdventurePlayer.add_card]: false when the bag is full).
static func take_spell(player: AdventurePlayer, card_name: String) -> bool:
	return player.add_card(card_name)


## "THE LOCATION OF WORLDMAGIC CARDS?" (E:1947–1987): the World Magics not
## yet owned, by their index in [constant AdventurePlayer.WORLD_MAGICS];
## empty when all are ("You have already gathered all of the WORLDMAGIC
## SPELLS!").
static func magic_choices(player: AdventurePlayer) -> Array[int]:
	var out: Array[int] = []
	for i in AdventurePlayer.WORLD_MAGICS.size():
		if not player.owns(AdventurePlayer.WORLD_MAGICS[i]):
			out.append(i)
	return out


## WORLD MAGIC [param index] FOUND: the town that sells it is marked visited
## (it shows in the city list) and its tile seen on the map (1997's status
## bit 2 and map flag 0x80), and the words "%1 may be found in %2." — the
## world map comes next ([EncounterPane]). Its lines; the bare "may be found"
## words with no town when none sells it now.
static func reveal_magic(player: AdventurePlayer, index: int) -> Array[String]:
	var magic: String = AdventurePlayer.WORLD_MAGICS[clampi(index, 0, AdventurePlayer.WORLD_MAGICS.size() - 1)]
	var world := player.world
	var town := WorldMagicShop.seller(world, index)
	if world == null or town <= 0 or town >= world.sites.size():
		return lines_of(MAGIC_FOUND % [magic, "Shandalar"])
	TownStatus.put(world, town, TownStatus.VISITED)
	var x := int(world.sites[town]["x"])
	var y := int(world.sites[town]["y"])
	if x >= 0 and y >= 0 and x < ShandalarWorld.TILES and y < ShandalarWorld.TILES:
		world.page[y * ShandalarWorld.PAGE_WIDTH + x] = world.page[y * ShandalarWorld.PAGE_WIDTH + x] \
			| ShandalarWorld.EXPLORED
	return lines_of(MAGIC_FOUND % [magic, WorldNames.site_name(world, town)])


## "SECRETS FROM THE CASTLE?" (E:1988–2009): the wizard beaten, "You have
## already destroyed the %s"; else, while the castle's three clues are not
## all known, one more is learned ([method WorldClues.reveal]); then what is
## known of it, as the clue screen shows it. The lines.
static func secrets(player: AdventurePlayer, meeting: Dictionary) -> Array[String]:
	var color := clampi(int(meeting["color"]), 1, 5)
	if AdventurePlayer.COLORS[color - 1] in player.defeated_wizards:
		return lines_of(DESTROYED % WorldNames.CASTLES[color - 1])
	var world := player.world
	var castle := color - 1
	if world == null or castle >= world.encounters.size():
		return [] as Array[String]
	if int((world.encounters[castle] as Dictionary).get("clues", 0)) & 7 != 7:
		WorldClues.reveal(player, castle)
	var out: Array[String] = [WorldClues.title(castle)]
	out.append_array(WorldClues.lines(world, castle))
	return out


# ------------------------------------------------------- the duel set up --

## THE DUEL PREPARED (E:2113–2224): the hand modifier, the creature's colour
## filter and, on a special meeting (`(monster_timer >> 2) % 3 == 0`, which
## plays `dsummon.wav` — the pane's), its events in 1997's order on the
## adventure's dice: "Try this deck" (the Conjurer, the High Priest, Whim:
## one time in three, a row 1–35's deck), a summons (the Witch, the Seer,
## the Enchantress, the Sorceress: one time in three, never the quest's
## creature — the next 1–3 rows, not 55 nor a castle wizard; strength the
## met creature's base + the new tier / 2), then the new creature's own: its
## card in play (when the modifier is not below 0), First Strike, Mind
## Control (when `monster_timer % 3 == 0`). The lines said, in order (1997
## showed each in its own box). Once only.
static func prepare_duel(player: AdventurePlayer, meeting: Dictionary) -> Array[String]:
	if bool(meeting.get("prepared", false)):
		return meeting.get("events", [] as Array[String])
	meeting["prepared"] = true
	var kind := int(meeting["kind"])
	var color := clampi(int(meeting["color"]), 1, 5)
	var d := clampi(player.difficulty, 0, 3)
	var hero_colors := DuelSpoils.deck_color_bits(player)
	var total := player.total_wins()
	var filter := player.learned_deck_colors(color)
	if kind >= CreatureBook.HENCHMAN:
		filter = hero_colors
	var modifier := -clampi(3 - total / 3, 0, 3)
	# [Ours: 1997 slip — a henchman's modifier was read from a World Magic's
	# price at a stale index (E:2138–2140); 0, as for every kind from 11.]
	if d == 3 or kind >= CreatureBook.HENCHMAN:
		modifier = 0
	if -d < modifier:
		filter = hero_colors
	var timer := int(meeting.get("timer", player.monster_timer))
	var special := ((timer >> 2) % 3) == 0
	var events: Array[String] = []
	meeting["total_wins"] = total
	meeting["modifier"] = modifier
	meeting["special"] = special
	meeting["swap_row"] = 0
	meeting["summoned"] = 0
	meeting["card"] = ""
	meeting["first_strike"] = false
	meeting["mind_control"] = false
	if special:
		var dice := MsvcRandom.new(player.dice)
		var row := int(meeting["row"])
		var flags := CreatureBook.preduel_flags(row)
		if flags & CreatureBook.PRE_SWAP != 0 and dice.below(3) == 0:
			# [Ours: 1997 slip — the filter is left as it was.]
			meeting["swap_row"] = dice.below(35) + 1
			events.append(TRY_DECK)
		if flags & CreatureBook.PRE_SUMMON != 0 and dice.below(3) == 0 and not bool(meeting["quest"]):
			var called := row
			while true:
				called = row + dice.below(3) + 1
				if called != 55 and not (called < 36 and called % 7 == 0):
					break
			events.append(SUMMONS % [CreatureBook.name_of(row), CreatureBook.called(called)])
			meeting["summoned"] = called
			meeting["row"] = called
			meeting["kind"] = CreatureBook.kind(called)
			meeting["strength"] = int(meeting["base_strength"]) + CreatureBook.tier(called) / 2
			row = called
		player.dice = dice.state
		flags = CreatureBook.preduel_flags(row)
		if flags & CreatureBook.PRE_CARD != 0:
			meeting["card"] = CreatureBook.reward_card(row)
		if flags & 0xCB != 0:
			var said := ""
			var shown := true
			var name := CreatureBook.name_of(row)
			if flags & CreatureBook.PRE_MIND != 0:
				# [Ours: 1997 slip — Mind Control only when announced.]
				if timer % 3 != 0:
					shown = false
				else:
					said = MIND_CONTROL % name
					meeting["mind_control"] = true
			if flags & CreatureBook.PRE_FIRST != 0:
				meeting["first_strike"] = true
				said = FIRST_STRIKE % name
			if flags & CreatureBook.PRE_CARD != 0:
				if modifier < 0 or String(meeting["card"]) == "":
					meeting["card"] = ""
					shown = false
				else:
					said = HAS_CARD % [name, String(meeting["card"])]
			if shown and said != "":
				events.append(said)
	meeting["filter"] = filter
	meeting["events"] = events
	return events


## THE HERO'S LIFE in the duel (duel.c 2205–2226): a life for each linked
## town or city no wizard rules ([method AdventurePlayer.mana_links]), and
## the next duel's lives — the carried ones and the gift
## ([method AdventurePlayer.next_duel_lives]); no floor (0 loses at once).
## DESIGNED, NEVER USED: [constant LIFE_BASE] and [constant LIFE_BONUSES]
## (see the class doc).
static func hero_life(player: AdventurePlayer) -> int:
	return player.mana_links() + player.next_duel_lives()


## THE CREATURE'S LIFE ([method CreatureBook.duel_life]) for the creature
## fought, at the hero's difficulty — a henchman's with the hero's World
## Magics, a castle wizard's with the wins over its colour and the towns it
## rules (`extras.towns`; [param extras] merged in, `tier` an override).
static func creature_life(player: AdventurePlayer, meeting: Dictionary, extras := {}) -> int:
	var more := {"world_magics": player.world_magics, "wins": player.wins_over_color(int(meeting["color"]))}
	more.merge(extras, true)
	return CreatureBook.duel_life(int(meeting["row"]), player.difficulty, more)


## THE DUEL THE MEETING HANDS TO THE ENGINE (play_duel's Shandalar branch,
## duel.c 2132–2526, set up as [DuelConfig]'s adventure fields; seat 0 the
## hero, seat 1 the creature): [method prepare_duel] first when it was not.
##  - The hero's deck: the deck in use, padded for this duel with random
##    basic lands (`rand(5)`, the adventure's dice) to [constant DECK_LEAST]
##    by difficulty, the stake lifted out of it (`ante_cards`); under "Try
##    this deck" a row's deck instead, the hero's own card staked from
##    outside it (`ante_extras`), no padding (1997 played that library).
##  - The creature's: its maindeck and the colour sections of its filter
##    ([method CreatureDeck.for_meeting]; `.vNone` never — the owner's
##    ruling 3), its stake lifted out of it, or made into its ante when the
##    deck lacks it (a summoned creature's).
##  - Lives: [method hero_life], [method creature_life].
##  - First player: the creature on First Strike, else the hero with the
##    first-move gift, else 1997's coin (−1) — the computer choosing play or
##    draw at random (`ai_random_play_or_draw`).
##  - Cards in play: the creature's card; the hero's next-duel card.
##  - Mind Control: `mirror_seat0`. 1997's mulligan (`mulligan_rule`).
##  - Faces: the hero's portrait and the creature's (`rogue_<name>`); the
##    names; the computer at the hero's difficulty; the player's own rules
##    options ([DuelOpening]); a fresh seed.
static func duel_config(player: AdventurePlayer, meeting: Dictionary) -> DuelConfig:
	if not bool(meeting.get("prepared", false)):
		prepare_duel(player, meeting)
	var row := int(meeting["row"])
	var config := DuelConfig.new()
	var hero_ante: Array = meeting.get("hero_ante", [])
	var swap := int(meeting.get("swap_row", 0))
	var hero_deck: Array = []
	if swap > 0:
		hero_deck = CreatureDeck.for_meeting(swap, 0)
		config.ante_extras[0] = hero_ante.duplicate()
	else:
		hero_deck = padded_deck(player, player.deck_cards())
		config.ante_cards[0] = hero_ante.duplicate()
	var creature_deck: Array = CreatureDeck.for_meeting(row, int(meeting.get("filter", 0)))
	for stake in meeting.get("creature_ante", []):
		if String(stake) in creature_deck:
			(config.ante_cards[1] as Array).append(String(stake))
		else:
			(config.ante_extras[1] as Array).append(String(stake))
	config.decks = [hero_deck, creature_deck]
	config.player_names = [player.name if player.name != "" else "Hero", CreatureBook.duel_name(row)]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [CreatureBook.name_of(swap) if swap > 0 else
		(deck_name if deck_name != "" else "Deck %d" % (player.current_deck + 1)), CreatureBook.name_of(row)]
	config.portraits = [player.portrait, CreatureBook.face_id(row)]
	config.lives = [hero_life(player), creature_life(player, meeting)]
	config.pilots = [null, ai_for(player.difficulty)]
	if bool(meeting.get("first_strike", false)):
		config.first_player = 1
	elif player.next_duel_first_move:
		config.first_player = 0
	var in_play: Array = [[], []]
	if player.next_duel_card != "":
		(in_play[0] as Array).append(player.next_duel_card)
	if String(meeting.get("card", "")) != "":
		(in_play[1] as Array).append(String(meeting["card"]))
	config.start_in_play = in_play
	config.mirror_seat0 = bool(meeting.get("mind_control", false))
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.ai_random_play_or_draw = true
	config.pace = Settings.ai_pace()
	config.rng_seed = randi() | 1
	config.apply_deck_colors()
	return config


## THE DECK IN USE MADE UP TO THE DIFFICULTY'S LEAST ([constant DECK_LEAST],
## the stake counted): [param cards] and random basic lands
## (`AddCardToDeckSorted(internal_rand(5))`, duel.c 2340–2346 — the five
## basic lands, [constant CreatureDeck.BASICS]) on the adventure's dice, for
## the duel only (1997 restored the deck after it).
static func padded_deck(player: AdventurePlayer, cards: Array) -> Array:
	var out := cards.duplicate()
	var least: int = DECK_LEAST[clampi(player.difficulty, 0, 3)]
	if out.size() >= least:
		return out
	var dice := MsvcRandom.new(player.dice)
	while out.size() < least:
		out.append(CreatureDeck.BASICS[dice.below(5)])
	player.dice = dice.state
	return out


## The computer's preset at difficulty [param difficulty] (0 Apprentice …
## 3 Wizard).
static func ai_for(difficulty: int) -> AiProfile:
	match clampi(difficulty, 0, 3):
		1:
			return AiProfile.magician()
		2:
			return AiProfile.sorcerer()
		3:
			return AiProfile.wizard()
	return AiProfile.apprentice()


## The creature's face (a [PortraitLibrary] id) for the creature fought now.
static func face(meeting: Dictionary) -> String:
	return CreatureBook.face_id(int(meeting.get("row", 0)))


## 1997's text broken at its `\n`, the trailing break dropped.
static func lines_of(text: String) -> Array[String]:
	var out: Array[String] = []
	for line in text.strip_edges().split("\n"):
		out.append(line)
	return out
