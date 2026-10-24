class_name DuelSpoils
extends RefCounted
## WHAT A DUEL WITH A CREATURE OF THE MAP LEAVES — 1.3's
## `RunWorldLairMonsterEncounter` after `RunDuelEngine` returns
## (world_lair_monster_encounter.c 2259–2691, the "E" lines below; the
## after-duel reset in `RunDuelEngine`, visitLocation.c 2201–2245),
## headless: [method settle] reads the meeting ([CreatureMeeting]) and the
## duel's [DuelReport] and changes the adventure; the record it returns is
## what the result panes show ([EncounterPane]).
##
## EVERY DUEL, WHATEVER CAME OF IT: every next-duel gift is spent first
## ([method AdventurePlayer.clear_duel_gifts] — the lives carried, the
## extra lives, the first move, the card in play; 1997 cleared them as the
## duel ended, before any spoils, so a win's new gifts stand), and the
## hero's deck is the deck it was (1997 restored it): THE CARDS GO BACK TO
## THEIR OWNERS — a change of owner during the duel (a Tempest Efreet, a
## Bronze Tablet, a Darkpact: [member DuelReport.owner_changes]) moves no
## card of the adventure, and the stakes are settled from the meeting's own
## antes, not the duel's ante zone (the lead's default under ruling 12).
##
## A WIN (E:2259–2647):
##  - the victory logged — the creature actually fought (a summons'), on
##    the slot's colour ([method AdventurePlayer.log_victory]); the journal
##    "Defeated %s" with the article (`@LOGSTRINGS` 4); the quest's creature
##    beaten, "Return to …" ([method Quests.creature_beaten]);
##  - kinds 1–10 only ([method CreatureBook.gives_spoils]):
##     - THE CARDS ([method reward_cards]): a budget of the creature's
##       strength S; each card a type drawn of six (land, creature,
##       enchantment, sorcery, instant, interrupt — a plain artifact never),
##       of a colour that goes with the creature's (level 3 for the 1st,
##       3rd … picks, 1 for the others), with a copy left for the deck in
##       use, not a treasure; the first picks the creature's own stake; each
##       costs its rarity (1–4, +1 for 1997's 0x400 cards). [Ours: 1997 slip
##       — eleven picks overflowed its ten-place array (S 11, all commons):
##       the pick has no limit here.] 1997 drew a height for each card shown
##       (`rand(10)`), kept for the pane.
##     - THE CLUE INSTEAD (E:2309–2391): when a castle or dungeon still has
##       a clue to give ([method WorldClues.pick_for_hint], picked before
##       the cards), its plaque shows — its name, its treasures, "(first
##       clue)" … — every slot's cards-taken mark fades one time in three
##       ([method WorldClues.forget_marks]), and the hero chooses ([method
##       choose]): "Take the cards." (the slot marked, [method
##       WorldClues.mark_cards_taken]) or "Take the dungeon clue." (one more
##       clue, the cards forfeited — the creature's stake with them).
##       [Ours: 1997 slip — any answer but the first, Escape too, took the
##       clue; Escape takes the cards (the pane's).]
##     - the cards join the collection, in no deck ([method
##       AdventurePlayer.add_card]: "Acquired spell" for a rare; the 500-card
##       bag full, a card is lost); from 450 cards the note "Your magic bag
##       only holds 500 spells…" (`@ENCOUNTER_POSTDUEL` 31);
##     - AN AMULET of the creature's colour one time in `40 / S`
##       (`rand(40) < S`);
##     - THE REWARD (special meetings only, E:2416–2632): the creature's
##       reward flags; with none and no amulet, `(1 << rand(12)) & 0x1A19`
##       — lives carried, gold, the first move, food or more lives, each one
##       time in twelve; the title by difficulty and the hero's gender
##       ("You are a Mighty Sorceress / Sorceror says the %s:", 1997's
##       spelling; [ours: a walker neither male nor female gets the
##       masculine word, as 1997's two-way test gave]); the gifts: the
##       lives carried (end life − start life), 1–4 more lives, teleported
##       to a land tile, the creature's card won, the first move, its card
##       in play, a random artifact in play, 20–49 food, any card of the
##       hero's choice (must pick), a copy of one of the hero's own cards
##       (may cancel), 100 gold;
##     - THE COLOUR LEARNS one time in `64 / (difficulty + 1) / S`: the
##       creatures of its colour add the hero's deck colours' sections to
##       their decks from now on ([method deck_color_bits], [method
##       AdventurePlayer.learn_deck_colors]); the rules learning's die is
##       drawn too (inert: no deck has a rules section).
## A LOSS (E:2648–2668): "Lost to %s"; the hero's stake leaves the
## collection ("Lost this card" each, [method CreatureMeeting.lose_stake]).
## A DRAW (E:2669–2691): nothing is logged or lost — "The people are
## disappointed…", "Better Luck Next Time!".
## Henchmen win the hero only the log, the journal and the quest (their
## spoils are DESIGNED, NEVER USED — `docs/adventure-unused-1997-features.md`
## §12; the random reward's unreachable duplicate, §11).
##
## [Ours] A conceded duel ("Exit duel" in an adventure duel) is a loss.
## [Ours] A henchman beaten, or a win with nothing to give, still says so
## on a pane ([member Dictionary] `won_words`); 1997 went back to the map
## after its wizards' window (`ShowStatsWindow(2, …)`, E:2266), which is not
## ours yet (an open question of part B).

const WON := 1
const LOST := 0
const DRAWN := -1
## `@LOGSTRINGS` 4 and 5, with the creature's article.
const DEFEATED := "Defeated %s"
const LOST_TO := "Lost to %s"
## `@ENCOUNTER_POSTDUEL`: 3/4 the hint's question (alike), 5 its answers,
## 6 the cards won, 7 the amulet, 8–15 the titles (female first), 16–26 the
## rewards, 27 the stake lost, 28/29 the draw (alike), 30, 31 the bag.
const SLIMY := "You have defeated the\nslimy %s.\nWill you..."
const TAKE_CARDS := "Take the cards."
const TAKE_CLUE := "Take the dungeon clue."
const WON_CARDS := "Won these cards."
const WON_AMULET := "Won this Amulet."
const TITLES: Array[Array] = [
	["You are an Adequate Apprentice\nsays the %s:", "You are an Adequate Apprentice\nsays the %s:"],
	["You are a Skillful Magician\nsays the %s:", "You are a Skillful Magician\nsays the %s:"],
	["You are a Mighty Sorceress\nsays the %s:", "You are a Mighty Sorceror\nsays the %s:"],
	["You are a Fearsome Wizardess\nsays the %s:", "You are a Fearsome Wizard\nsays the %s:"]]
const LIVES_CARRIED := "You get your lives (%d)\ncarried over to the next duel."
const MORE_LIVES := "You get +%d lives in next duel."
const TELEPORTED := "TELEPORTED!"
const WON_CARD := "You won card: %s"
const FIRST_MOVE := "You get first move\nin the next duel."
const CARD_NEXT := "You get %s in the next duel."
const EXTRA_FOOD := "You get Extra FOOD!"
const ANY_CARD := "You get any card of your choice!"
const DUPLICATE := "You get a duplicate card\nof your choice!"
const PICK_CARD := "Pick a card"
const EXTRA_GOLD := "You get Extra GOLD!"
const LOST_CARD := "Lost this card"
const DRAW_WORDS := "The people are disappointed\nyou could manage no better than a draw\nagainst the slimy %s."
const BETTER_LUCK := "Better Luck Next Time!"
const BAG_NOTE := "Note:\nYour magic bag only holds 500 spells\nand you currently have %d"
## `@BROWSE` 13–16: the cards' captions by rarity.
const RARITY_WORDS: Array[String] = ["Common", "Uncommon", "Rare", "Unique"]
## The reward pick's six types (1997 type bits: land, creature,
## enchantment, sorcery, instant, interrupt).
const PICK_TYPES := 6
## `PickRandomCardMatchingTypeAndColor`'s draws before it gives the last.
const TYPE_TRIES := 999
## [Ours] The reward pick's guard: 1997 drew until a card fitted, forever
## when none could; this many tries, then the pick ends.
const PICK_GUARD := 2000


# --------------------------------------------------------------- settled --

## THE DUEL OF [param meeting] SETTLED from [param report] (see the class
## doc): the adventure changed, and the record the panes show —
## `{result, row, color, name, journal, quest, conceded, cards, rarities,
## heights, hint, plaque, asks, took, clue, kept, bag_lost, bag, amulet,
## bits, title, rewards, reward_card, pick_any, pick_duplicate, picked,
## teleported, learned, lost, words}`. With a clue to offer (`asks`) the
## cards wait for [method choose]; the rest of the spoils come with it.
static func settle(player: AdventurePlayer, meeting: Dictionary, report: DuelReport) -> Dictionary:
	var row := int(meeting["row"])
	var result := LOST if report == null or bool(meeting.get("conceded", false)) else report.result
	if report != null and not report.finished and not bool(meeting.get("conceded", false)):
		result = DRAWN
	var spoils := {"result": result, "row": row, "color": int(meeting["color"]),
		"name": CreatureBook.name_of(row), "journal": "", "quest": false,
		"conceded": bool(meeting.get("conceded", false)),
		"cards": [] as Array[String], "rarities": [] as Array[int], "heights": [] as Array[int],
		"hint": -1, "plaque": {}, "asks": false, "took": "", "clue": [] as Array[String],
		"kept": [] as Array[String], "bag_lost": [] as Array[String], "bag": 0, "amulet": "",
		"bits": 0, "title": "", "rewards": [] as Array[String], "reward_card": "",
		"pick_any": false, "pick_duplicate": false, "picked": "", "teleported": false,
		"learned": false, "lost": [] as Array[String], "words": [] as Array[String],
		"lives_start": report.lives_start[0] if report != null else 0,
		"lives_end": report.lives_end[0] if report != null else 0,
		"special": bool(meeting.get("special", false)), "strength": int(meeting.get("strength", 0))}
	player.clear_duel_gifts()
	match result:
		WON:
			_won(player, meeting, spoils)
		LOST:
			spoils["journal"] = LOST_TO % CreatureBook.called(row)
			player.log_event("duel", spoils["journal"], {"won": false, "creature": CreatureBook.name_of(row),
				"row": row, "color": int(meeting["color"])})
			spoils["lost"] = CreatureMeeting.lose_stake(player, meeting)
		_:
			var words: Array[String] = []
			words.append_array(lines_of(DRAW_WORDS % CreatureBook.name_of(row)))
			words.append(BETTER_LUCK)
			spoils["words"] = words
	return spoils


static func _won(player: AdventurePlayer, meeting: Dictionary, spoils: Dictionary) -> void:
	var row := int(meeting["row"])
	var color := int(meeting["color"])
	player.log_victory(row, color)
	spoils["journal"] = DEFEATED % CreatureBook.called(row)
	player.log_event("duel", spoils["journal"], {"won": true, "creature": CreatureBook.name_of(row),
		"row": row, "color": color})
	spoils["quest"] = Quests.creature_beaten(player, row)
	if not CreatureBook.gives_spoils(row):
		spoils["words"] = [spoils["journal"] + "."] as Array[String]
		return
	spoils["hint"] = WorldClues.pick_for_hint(player)
	var dice := MsvcRandom.new(player.dice)
	var cards := reward_cards(player, meeting, dice)
	var rarities: Array[int] = []
	var heights: Array[int] = []
	for card_name in cards:
		rarities.append(_rarity(card_name))
		heights.append(dice.below(10))
	player.dice = dice.state
	spoils["cards"] = cards
	spoils["rarities"] = rarities
	spoils["heights"] = heights
	var hint := int(spoils["hint"])
	if hint >= 0:
		spoils["plaque"] = {"name": WorldNames.dungeon_name(hint),
			"cards": ", ".join(PackedStringArray(WorldClues.treasures(player.world, hint))),
			"clue": WorldClues.clue_word(player.world, hint)}
		WorldClues.forget_marks(player)
		spoils["asks"] = true
		spoils["words"] = lines_of(SLIMY % CreatureBook.name_of(row))
		return
	_keep_cards(player, spoils)
	spoils["took"] = "cards"
	spoils["words"] = [WON_CARDS] as Array[String]
	_after_cards(player, meeting, spoils)


## THE HINT'S QUESTION ANSWERED ([param take_cards]: "Take the cards." or
## "Take the dungeon clue."), then the rest of the spoils — the amulet, the
## reward, the colour learning. Nothing when no question waits.
static func choose(player: AdventurePlayer, meeting: Dictionary, spoils: Dictionary, take_cards: bool) -> void:
	if not bool(spoils.get("asks", false)):
		return
	spoils["asks"] = false
	var hint := int(spoils["hint"])
	if take_cards:
		WorldClues.mark_cards_taken(player.world, hint)
		_keep_cards(player, spoils)
		spoils["took"] = "cards"
	else:
		WorldClues.reveal(player, hint)
		var clue: Array[String] = [WorldClues.title(hint)]
		clue.append_array(WorldClues.lines(player.world, hint))
		spoils["clue"] = clue
		spoils["took"] = "clue"
	_after_cards(player, meeting, spoils)


## The cards won join the collection, in no deck; a card the full bag
## cannot hold is lost (`bag_lost`).
static func _keep_cards(player: AdventurePlayer, spoils: Dictionary) -> void:
	var kept: Array[String] = []
	var lost: Array[String] = []
	for card_name in spoils["cards"]:
		if player.add_card(String(card_name)):
			kept.append(String(card_name))
		else:
			lost.append(String(card_name))
	spoils["kept"] = kept
	spoils["bag_lost"] = lost


## After the cards (E:2392–2645): the bag's note, the amulet, the reward,
## the colour learning.
static func _after_cards(player: AdventurePlayer, meeting: Dictionary, spoils: Dictionary) -> void:
	if player.cards.size() >= AdventurePlayer.BAG_WARN:
		spoils["bag"] = player.cards.size()
	var row := int(meeting["row"])
	var color := clampi(int(meeting["color"]), 1, 5)
	var strength := int(meeting.get("strength", CreatureBook.strength(row)))
	var special := bool(meeting.get("special", false))
	var dice := MsvcRandom.new(player.dice)
	var bits := CreatureBook.reward_flags(row) if special else 0
	if dice.below(40) < strength:
		var hue: String = AdventurePlayer.COLORS[color - 1]
		player.amulets[hue] = int(player.amulets.get(hue, 0)) + 1
		spoils["amulet"] = hue
	elif bits == 0 and special:
		bits = (1 << dice.below(12)) & CreatureBook.REWARD_RANDOM
	spoils["bits"] = bits
	if bits != 0:
		spoils["title"] = title_for(player, row)
		_rewards(player, row, bits, spoils, dice)
	# The hero's deck colours, as 1997 recounted them while it drew the cards
	# (`GetRemainingAllowedCardCopies`) and kept them in its save
	# (`g_deck_color_bitmap`, [member AdventurePlayer.deck_colors]).
	var hero_colors := deck_color_bits(player)
	player.deck_colors = color_names(hero_colors)
	if dice.below(64 / (clampi(player.difficulty, 0, 3) + 1)) < strength:
		player.learn_deck_colors(color, hero_colors)
		spoils["learned"] = true
	# The rules learning: 1997's `g_duel_special_rules_by_color`, unsaved and
	# read by no deck (DESIGNED, NEVER USED, §8) — its die is still cast.
	dice.below(128 / (clampi(player.difficulty, 0, 3) + 1))
	player.dice = dice.state


## THE REWARD'S GIFTS of [param bits], in 1997's order (E:2514–2632), on
## [param dice]: the lines said, the card shown, the picks to come.
static func _rewards(player: AdventurePlayer, row: int, bits: int, spoils: Dictionary, dice: MsvcRandom) -> void:
	var lines: Array[String] = []
	var left := bits
	if left & CreatureBook.REWARD_LIFE_CARRIED != 0 and int(spoils["lives_end"]) != int(spoils["lives_start"]):
		player.next_duel_life_carried = int(spoils["lives_end"]) - int(spoils["lives_start"])
		lines.append_array(lines_of(LIVES_CARRIED % int(spoils["lives_end"])))
	if left & CreatureBook.REWARD_LIVES != 0:
		player.next_duel_life = dice.below(4) + 1
		lines.append(MORE_LIVES % player.next_duel_life)
	if left & CreatureBook.REWARD_TELEPORT != 0 and player.world != null:
		var x := 0
		var y := 0
		while true:
			x = dice.below(ShandalarWorld.TILES)
			y = dice.below(ShandalarWorld.TILES)
			if player.world.is_land(x, y):
				break
		player.position = Vector2i(x * 32 + 16, y * 32 + 16)
		player.world.explore_around(player.tile())
		spoils["teleported"] = true
		lines.append(TELEPORTED)
	if left & CreatureBook.REWARD_WON_CARD != 0:
		var card := CreatureBook.reward_card(row)
		if CardRegistry.has_card(card):
			if player.add_card(card):
				(spoils["kept"] as Array[String]).append(card)
			else:
				(spoils["bag_lost"] as Array[String]).append(card)
			spoils["reward_card"] = card
			lines.append(WON_CARD % card)
	if left & CreatureBook.REWARD_FIRST_MOVE != 0:
		player.next_duel_first_move = true
		lines.append_array(lines_of(FIRST_MOVE))
	if left & CreatureBook.REWARD_CARD_NEXT != 0:
		var card := CreatureBook.reward_card(row)
		if CardRegistry.has_card(card):
			player.next_duel_card = card
			spoils["reward_card"] = card
			lines.append(CARD_NEXT % card)
	if left & CreatureBook.REWARD_ARTIFACT_NEXT != 0:
		var artifact := _random_artifact(dice)
		if artifact != "":
			player.next_duel_card = artifact
			spoils["reward_card"] = artifact
			lines.append(CARD_NEXT % artifact)
	if left & CreatureBook.REWARD_FOOD != 0:
		player.food += dice.below(30) + 20
		lines.append(EXTRA_FOOD)
	if left & CreatureBook.REWARD_ANY_CARD != 0:
		spoils["pick_any"] = true
		lines.append(ANY_CARD)
		left = 0
	if left & CreatureBook.REWARD_DUPLICATE != 0:
		spoils["pick_duplicate"] = true
		lines.append_array(lines_of(DUPLICATE))
		left = 0
	if left & CreatureBook.REWARD_GOLD != 0:
		player.gold += 100
		lines.append(EXTRA_GOLD)
	spoils["rewards"] = lines


## A random non-creature artifact for the next duel (E:2556–2567: a card
## drawn until it is an artifact and not a creature), "" when the pool has
## none.
static func _random_artifact(dice: MsvcRandom) -> String:
	var pool := CardTrade.catalogue()
	if pool.is_empty():
		return ""
	for attempt in PICK_GUARD:
		var row: Dictionary = pool[dice.below(pool.size())]
		var kind := int((row["facts"] as Dictionary).get("type", 0))
		if kind & (CardValue.ARTIFACT | CardValue.CREATURE) == CardValue.ARTIFACT:
			return String(row["name"])
	return ""


## "YOU GET ANY CARD OF YOUR CHOICE!" — [param card_name] picked from every
## card ([method CardTrade.catalogue]) joins the collection. 1997 asked
## again until a card was picked (E:2604–2612): the pane does.
static func pick_any(player: AdventurePlayer, spoils: Dictionary, card_name: String) -> bool:
	if not bool(spoils.get("pick_any", false)) or not CardRegistry.has_card(card_name):
		return false
	spoils["pick_any"] = false
	spoils["picked"] = card_name
	return player.add_card(card_name)


## "YOU GET A DUPLICATE CARD OF YOUR CHOICE!" — a copy of [param card_name],
## one of the hero's own (E:2614–2631; "" or a card not owned cancels, as
## 1997 let it).
static func pick_duplicate(player: AdventurePlayer, spoils: Dictionary, card_name: String) -> bool:
	if not bool(spoils.get("pick_duplicate", false)):
		return false
	spoils["pick_duplicate"] = false
	var owned := false
	for entry in player.cards:
		if String((entry as Dictionary).get("card", "")) == card_name:
			owned = true
			break
	if not owned:
		return false
	spoils["picked"] = card_name
	return player.add_card(card_name)


# --------------------------------------------------------------- the cards --

## THE CARDS WON (E:2273–2295): drawn on [param dice] while the budget — the
## creature's strength — lasts (see the class doc). The creature's stake is
## among the first three picks (its first card the first pick).
static func reward_cards(player: AdventurePlayer, meeting: Dictionary, dice: MsvcRandom) -> Array[String]:
	var out: Array[String] = []
	var pool := CardTrade.catalogue()
	var color := clampi(int(meeting["color"]), 1, 5)
	var stakes: Array = meeting.get("creature_ante", [])
	# The copy limit as the Embark chose it ([method CardShop.counted_copies]).
	var counts := CardShop.counted_copies(player)
	var limit := CardShop.copies_allowed(player)
	var budget := int(meeting.get("strength", CreatureBook.strength(int(meeting["row"]))))
	var present := _types_in(pool)
	while budget > 0:
		var picked := ""
		if not pool.is_empty():
			for attempt in PICK_GUARD:
				var bit := 1 << dice.below(PICK_TYPES)
				# [Ours: without the player's 1997 card table no card is typed
				# an interrupt ([method CardValue.derive]); a type no card has
				# is drawn again — else its 999 tries ended on any card at
				# all, a plain artifact among them, which 1997 never gave (the
				# bug pass of part B, q4-2). With the table every type has
				# cards and the dice are 1997's.]
				var again := 0
				while present & bit == 0 and present != 0 and again < PICK_TYPES * 16:
					bit = 1 << dice.below(PICK_TYPES)
					again += 1
				var drawn: Dictionary = pool[0]
				for tries in TYPE_TRIES:
					drawn = pool[dice.below(pool.size())]
					if int((drawn["facts"] as Dictionary).get("type", 0)) & bit != 0:
						break
				var f: Dictionary = drawn["facts"]
				var level := 1 if out.size() & 1 != 0 else 3
				if not CardValue.goes_with(int(f.get("color", CardValue.COLORLESS)), 1 << color, level):
					continue
				if copies_left(player, String(drawn["name"]), f, counts, limit) <= 0:
					continue
				picked = String(drawn["name"])
				break
		if out.size() < 3 and out.size() < stakes.size():
			picked = String(stakes[out.size()])
		if picked == "":
			break
		out.append(picked)
		budget -= maxi(_rarity(picked) + _favoured(picked), 1)
	return out


## The reward's types ([constant PICK_TYPES] bits) some card of [param pool]
## has.
static func _types_in(pool: Array) -> int:
	var all := (1 << PICK_TYPES) - 1
	var found := 0
	for drawn in pool:
		found |= int(((drawn as Dictionary)["facts"] as Dictionary).get("type", 0)) & all
		if found == all:
			break
	return found


## The copies of [param card_name] the deck in use may still take
## (`GetRemainingAllowedCardCopies`, adventure_new_game.c 425–512): the
## deck's limit (one, two from 40 cards, three from 60, one more with Tome
## of Enlightenment, [method CardShop.copies_allowed] — [param limit]),
## halved for a card outside the base sets, less the copies in the deck
## ([param counts]); a basic land always 99.
static func copies_left(player: AdventurePlayer, card_name: String, f: Dictionary, counts: Dictionary,
		limit: int) -> int:
	if card_name in CreatureDeck.BASICS:
		return 99
	var allowed := limit
	if int(f.get("extra", 0)) & 0x100 != 0:
		allowed = 1 if player.difficulty <= allowed else 0
	elif not _is_base(card_name, f):
		allowed = allowed / 2
	return allowed - int(counts.get(card_name, 0))


## Whether a card is of the 1997 base sets (`expansion & 0xC1`; read off the
## card without the program's table, as [CardRiddle] does).
static func _is_base(card_name: String, f: Dictionary) -> bool:
	if not bool(f.get("derived", true)):
		return int(f.get("exp", 0)) & 0xC1 != 0
	return CardValue.is_base(card_name)


## A card's 1997 rarity (`GetCardRarity`, 1 common … 4 special;
## [method CardShop.shop_rarity]), 1 for a card the pool does not know.
static func _rarity(card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 1
	return clampi(CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card(card_name))), 1, 4)


## 1 for a card with the program's 0x400 mark (the reward pick's extra
## cost), else 0.
static func _favoured(card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 0
	return 1 if int(CardValue.facts(CardRegistry.get_card(card_name)).get("extra", 0)) & CardValue.FAVOURED != 0 else 0


## A card's caption under it on the cards won (`@BROWSE` 13–16).
static func rarity_word(rarity: int) -> String:
	return RARITY_WORDS[clampi(rarity, 1, 4) - 1]


# ------------------------------------------------------------- the words --

## THE REWARD SCREEN'S TITLE (E:2463–2508): by the difficulty and the hero's
## gender (`IsPlayerAvatarFemale`), naming the creature. [Ours: a walker
## that is neither male nor female gets the masculine word — 1997's test had
## two answers, and a hero not "female" read as male.]
static func title_for(player: AdventurePlayer, row: int) -> String:
	var pair: Array = TITLES[clampi(player.difficulty, 0, 3)]
	return String(pair[0 if player.walker == "female" else 1]) % CreatureBook.name_of(row)


## THE HERO'S DECK COLOURS (1997's `g_deck_color_bitmap`, computed in
## `GetRemainingAllowedCardCopies`, adventure_new_game.c 452–476): the
## deck in use's cards counted by colour — each card its first colour
## (black … white; a colourless card none) — and every colour holding at
## least two thirds of the most-held colour's count (integer thirds, as
## 1997 divided), as colour bits (0x02 black … 0x20 white). 0 for a deck of
## colourless cards only.
static func deck_color_bits(player: AdventurePlayer) -> int:
	var counts := {}
	for card_name in player.deck_cards():
		if not CardRegistry.has_card(card_name):
			continue
		var bit := CardValue.first_color(int(CardValue.facts(CardRegistry.get_card(card_name)).get("color",
			CardValue.COLORLESS)))
		if bit != 0:
			counts[bit] = int(counts.get(bit, 0)) + 1
	var most := 0
	for bit in counts:
		most = maxi(most, int(counts[bit]))
	var out := 0
	if most == 0:
		return 0
	for bit in counts:
		if int(counts[bit]) >= most * 2 / 3:
			out |= int(bit)
	return out


## The colour words of 1997 colour bits [param bits] (0x02 black … 0x20
## white), in [constant AdventurePlayer.COLORS]' order.
static func color_names(bits: int) -> Array[String]:
	var out: Array[String] = []
	for i in AdventurePlayer.COLORS.size():
		if bits & (2 << i) != 0:
			out.append(AdventurePlayer.COLORS[i])
	return out


## 1997's text broken at its `\n`.
static func lines_of(text: String) -> Array[String]:
	var out: Array[String] = []
	for line in text.strip_edges().split("\n"):
		out.append(line)
	return out
