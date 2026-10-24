class_name LairEvent
extends RefCounted
## WHAT A LAIR HOLDS (the owner, 2026-10-23: *"Build all trade features"*)
## — 1.3's `RunLairExplorationEvent` (0052fae0), in the words of `@LAIR`,
## `@LAIR_NAMES` and `@LOGSTRINGS`. A lair entered ([WorldLairs]):
##  - TWO TIMES IN THREE (the world's clock: `(T >> 2) % 3` not 0) a
##    TREASURE, "Found this card": half the time a basic land of the lair's
##    colour, else any card of its colour or none, any rarity — never a
##    dungeon's treasure.
##  - ELSE ONE OF FOURTEEN, alike in chance, "You happen upon a …!" (and
##    in the journal, "Discovered a …"): the Ruined Tower (a clue to the
##    castle or dungeon the dice favour, near ones most, those whose rules
##    0x200 least — or, none left to tell of, a riddle for a rare of the
##    lair's colour, as Loremaster's Tower), Loremaster's Tower (a riddle
##    [CardRiddle] for that rare), the Thieves Hideout (500 gold; or, once
##    the siege clock has run 128 steps, half the time thieves take half
##    the gold and leave a rare), the Nomad's Bazaar (any card for gold,
##    [CardTrade]), the Abandoned Shrine, the Dragon's Lair, the Hall of the
##    Sultan and the Spectral Arena (duels), the Gemcutter's Guild (amulets
##    for 200 gold each), the Pyramids of Aska-tet (a riddle for any rare),
##    the Lost City of El'Akram (an amulet of each colour; or, as the
##    Hideout, thieves take half the amulets, the half rounded to the hero,
##    and leave a rare), the Guardian's Ghost (an amulet to see a creature's
##    deck), the Oasis of Muldoon (an uncommon or rare card of the hero's
##    for five more life in the next duel) and the Diamond Mine (any card
##    for amulets). The Hall and the Oasis are drawn again while a gift for
##    the next duel waits.
##  - A QUARTER OF THE TIME, as the fourteen begin, a rare of any kind waits
##    too: given at the end ("Found this card"), unless the event gave
##    something else — a riddle answered gives its own rare instead; the
##    Hideout's and the Lost City's luck take it, their thieves leave
##    another.
## The four duels ([constant DUELS]) are [LairDuels]': a creature of the
## lair's tier and its hoard of rares, Leave quietly or Duel the creature —
## the waiting rare is given after, whatever came of it, as at every lair.
## The Guardian's Ghost shows a deck ([CreatureBook]). [Ours: 1997 hung on
## any lair while the hero held no uncommon or rare card, looking for one to
## offer at the Oasis; here the Oasis offers none.]

## `@LAIR_NAMES`, by event (0–4 the treasures of black … white, unshown).
const NAMES: Array[String] = ["Restless Graveyard", "Hallowed Ground", "Active Volcano",
	"Faerie Glade", "Hidden Lagoon", "Ruined Tower", "Loremaster's Tower", "Thieves Hideout",
	"Nomad's Bazaar", "Abandoned Shrine", "Dragon's Lair", "Hall of the Sultan",
	"Gemcutter's Guild", "Spectral Arena", "Pyramids of Aska-tet", "Lost City of El'Akram",
	"Guardian's Ghost", "Oasis of Muldoon", "Diamond Mine"]
## A treasure lair's name, by colour (black … white): 1997's first five lair
## names, never shown in 1.3, each given here to the colour it names.
const TREASURE_NAMES: Array[String] = ["Restless Graveyard", "Hidden Lagoon", "Faerie Glade",
	"Active Volcano", "Hallowed Ground"]
const RUINED_TOWER := 5
const LOREMASTER := 6
const THIEVES := 7
const BAZAAR := 8
const SHRINE := 9
const DRAGON := 10
const SULTAN := 11
const GEMCUTTER := 12
const ARENA := 13
const PYRAMIDS := 14
const LOST_CITY := 15
const GHOST := 16
const OASIS := 17
const MINE := 18
const DUELS: Array[int] = [SHRINE, DRAGON, SULTAN, ARENA]
const AMULET_PRICE := 200
const FOUND := "Found this card"
## The siege clock before thieves may win (`g_siege_timer < 0x80`).
const SAFE_SIEGE := 128

## Every card of the adventure ([method _cards]), and the card pool's
## revision it was read against (−1: not yet) — read again when a pack is
## turned on or off ([method CardValue.pool_moved]).
static var _treasures: Array[Dictionary] = []
static var _read_at := -1


## A LAIR BEGUN: what lair [param lair] (`{slot, color, …}`) holds, drawn
## now — `{slot, color, event, name, reward, lair_rare, oasis}`: `event`
## the treasure's colour (0–4) or 5–18; `reward` the card to be found at
## the end ("" none); `oasis` the place in the hero's cards the Oasis would
## take (−1 none).
static func begin(player: AdventurePlayer, lair: Dictionary) -> Dictionary:
	var dice := MsvcRandom.new(player.dice)
	var color := clampi(int(lair.get("color", 1)), 0, 5)
	var out := {"slot": int(lair.get("slot", -1)), "color": color, "reward": "", "oasis": -1}
	out["lair_rare"] = _lair_rare(player, dice, color)
	var dear: Array[int] = []
	for i in player.cards.size():
		var card_name := String((player.cards[i] as Dictionary).get("card", ""))
		if CardRegistry.has_card(card_name) \
				and CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card(card_name))) >= 2:
			dear.append(i)
	if not dear.is_empty():
		out["oasis"] = dear[dice.below(dear.size())]
	if (player.monster_timer >> 2) % 3 != 0:
		out["event"] = maxi(color - 1, 0)
		out["name"] = TREASURE_NAMES[out["event"]]
		if color >= 1 and dice.below(2) != 0:
			out["reward"] = CardShop.LANDS[color - 1]
		else:
			out["reward"] = _treasure(dice, color, CardShop.classic_rule(player))
		player.dice = dice.state
		return out
	var event := 0
	while true:
		event = dice.below(14) + 5
		if not (_gift_waiting(player) and event in [SULTAN, OASIS]):
			break
	out["event"] = event
	out["name"] = NAMES[event]
	if dice.below(4) == 0:
		out["reward"] = rare_of_any_kind(dice)
	player.dice = dice.state
	player.log_event("lair", "Discovered %s" % with_article(NAMES[event]))
	return out


## Whether [param event] (`begin`'s) is a treasure, found at once.
static func is_treasure(event: Dictionary) -> bool:
	return int(event.get("event", 0)) < RUINED_TOWER


## "You happen upon a Nomad's Bazaar!" ("an Abandoned Shrine" [ours: 1997
## wrote "a" before every name]).
static func arrival(event: Dictionary) -> String:
	return "You happen upon %s!" % with_article(String(event.get("name", "Lair")))


## [param name] with "a" or, before a vowel, "an".
static func with_article(name: String) -> String:
	return ("an " if name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name


static func _gift_waiting(player: AdventurePlayer) -> bool:
	return player.duel_gift_waiting()


# ------------------------------------------------------------ the events --

## THE THIEVES HIDEOUT: the words said; the gold and the waiting card
## changed.
static func thieves(player: AdventurePlayer, event: Dictionary) -> String:
	var dice := MsvcRandom.new(player.dice)
	var lucky := dice.below(2) != 0 or player.siege_timer < SAFE_SIEGE
	var said := ""
	if lucky:
		player.gold += 500
		event["reward"] = ""
		said = "You get 500 gold!"
	else:
		player.gold /= 2
		event["reward"] = rare_of_any_kind(dice)
		said = "Thieves take half your gold!"
	player.dice = dice.state
	return said


## THE LOST CITY OF EL'AKRAM, as the Hideout with amulets.
static func lost_city(player: AdventurePlayer, event: Dictionary) -> String:
	var dice := MsvcRandom.new(player.dice)
	var lucky := dice.below(2) != 0 or player.siege_timer < SAFE_SIEGE
	var said := ""
	for hue in AdventurePlayer.COLORS:
		var held := int(player.amulets.get(hue, 0))
		player.amulets[hue] = held + 1 if lucky else (held + 1) / 2
	if lucky:
		event["reward"] = ""
		said = "You find an amulet of each color!"
	else:
		event["reward"] = rare_of_any_kind(dice)
		said = "Thieves take half your amulets!"
	player.dice = dice.state
	return said


## THE GEMCUTTER'S GUILD: an amulet of [param color] for 200 gold; the
## words said.
static func buy_amulet(player: AdventurePlayer, color: String) -> String:
	if player.gold < AMULET_PRICE:
		return "Insufficient Funds"
	player.gold -= AMULET_PRICE
	player.amulets[color] = int(player.amulets.get(color, 0)) + 1
	return "You buy a %s amulet." % color


## The Gemcutter's offer for [param color]: " Buy a black amulet. (you have 2)".
static func amulet_words(player: AdventurePlayer, color: String) -> String:
	return "Buy a %s amulet. (you have %d)" % [color, int(player.amulets.get(color, 0))]


## THE OASIS OF MULDOON: the card it would take, or "".
static func oasis_card(player: AdventurePlayer, event: Dictionary) -> String:
	var at := int(event.get("oasis", -1))
	if at < 0 or at >= player.cards.size():
		return ""
	return String((player.cards[at] as Dictionary).get("card", ""))


## The Oasis's trade made: the card gone, five more life in the next duel.
static func oasis_trade(player: AdventurePlayer, event: Dictionary) -> String:
	var card_name := oasis_card(player, event)
	if card_name == "":
		return ""
	player.cards.remove_at(int(event["oasis"]))
	event["oasis"] = -1
	player.next_duel_life = 5
	return "Your %s is traded for five extra life in the next duel." % card_name


## THE RUINED TOWER: a clue told ([method WorldClues.reveal_for_hint]) —
## the castle or dungeon's slot whose clue is now known, or −1 when none is
## left to tell of (a riddle then).
static func ruined_tower(player: AdventurePlayer) -> int:
	return WorldClues.reveal_for_hint(player)


## A riddle answered at event [param event]: a right answer at
## Loremaster's Tower (or a Ruined Tower) gives the lair's rare, at the
## Pyramids a rare of any kind; a wrong one leaves the waiting card.
static func riddle_answered(player: AdventurePlayer, event: Dictionary, right: bool) -> void:
	if not right:
		return
	if int(event.get("event", 0)) == PYRAMIDS:
		var dice := MsvcRandom.new(player.dice)
		event["reward"] = rare_of_any_kind(dice)
		player.dice = dice.state
	else:
		event["reward"] = String(event.get("lair_rare", ""))


## THE END OF A LAIR: the card found, if any, is the hero's (in no deck).
static func finish(player: AdventurePlayer, event: Dictionary) -> String:
	var card_name := String(event.get("reward", ""))
	event["reward"] = ""
	if card_name == "" or not CardRegistry.has_card(card_name):
		return ""
	# Through the bag ([method AdventurePlayer.add_card], as 1997's adder):
	# lost when it is full, a rare written in the journal.
	if not player.add_card(card_name):
		return ""
	return card_name


# ------------------------------------------------------------ the cards --

## `PickRandomRareAvailableCard`: any card of the adventure, rare or
## special.
static func rare_of_any_kind(dice: MsvcRandom) -> String:
	var rares: Array[String] = []
	for row in _cards():
		if CardShop.shop_rarity(row["facts"]) >= 3:
			rares.append(String(row["name"]))
	return rares[dice.below(rares.size())] if not rares.is_empty() else ""


## The lair's rare (`reward_cards[3]`): two times in three a rare of its
## colour, not an artifact; else a rare artifact. Never one 1997 kept from
## trades (0x900); and, with the copy limit on ([method
## CardShop.counted_copies]), never one the deck in use holds more of than
## it may — 1997 threw such a card back (`GetRemainingAllowedCardCopies(card)
## < 0`, world_lair_monster_encounter.c 997–1001; [method
## DuelSpoils.copies_left]; the playtest of part B, P3-4): one it may take no
## more of still comes. Off, as 1997 shipped it, no copy is counted and none
## is thrown back. Under the Classic MTG rules none the hero holds every
## copy of they allow ([method CardShop.classic_allows]).
static func _lair_rare(player: AdventurePlayer, dice: MsvcRandom, color: int) -> String:
	var counts := CardShop.counted_copies(player)
	var limit := CardShop.copies_allowed(player) if not counts.is_empty() else 0
	var classic := CardShop.classic_rule(player)
	var spells: Array[String] = []
	var artifacts: Array[String] = []
	for row in CardTrade.catalogue():
		var f: Dictionary = row["facts"]
		if CardShop.shop_rarity(f) != 3:
			continue
		if not counts.is_empty() and DuelSpoils.copies_left(player, String(row["name"]), f, counts, limit) < 0:
			continue
		if not CardShop.classic_allows(classic, String(row["name"])):
			continue
		var kind := int(f.get("type", 0))
		if kind & CardValue.ARTIFACT != 0:
			artifacts.append(String(row["name"]))
		elif kind & 0x3F != 0 and (color == 0 or int(f.get("color", CardValue.COLORLESS)) & (1 << color) != 0):
			spells.append(String(row["name"]))
	var pick := spells if dice.below(3) != 0 and not spells.is_empty() else artifacts
	return pick[dice.below(pick.size())] if not pick.is_empty() else ""


## The treasure's card: any of the lair's colour [param color] or none,
## never a dungeon's — nor, under the Classic MTG rules, one they let no one
## offer the hero ([param classic]: [method CardShop.classic_rule]).
static func _treasure(dice: MsvcRandom, color: int, classic := {}) -> String:
	var found: Array[String] = []
	for row in _cards():
		var f: Dictionary = row["facts"]
		if int(f.get("extra", 0)) & 0x100 != 0 or bool(row["treasure"]):
			continue
		if not CardShop.classic_allows(classic, String(row["name"])):
			continue
		var bits := int(f.get("color", CardValue.COLORLESS))
		if color == 0 or bits == CardValue.COLORLESS or CardValue.first_color(bits) == 1 << color:
			found.append(String(row["name"]))
	return found[dice.below(found.size())] if not found.is_empty() else ""


## Every card of the adventure, once for the card pool as it stands:
## `{name, facts, treasure}`.
static func _cards() -> Array[Dictionary]:
	if CardValue.pool_moved(_read_at):
		forget()
	_read_at = CardRegistry.revision
	if not _treasures.is_empty():
		return _treasures
	CardRegistry.ensure_loaded()
	var held: Array[String] = []
	for row in ShandalarWorld.DUNGEON_CARDS:
		held.append(String(row[1]))
	for card_name in CardRegistry.all_names():
		var name_text := String(card_name)
		if CardTrade.in_adventure(name_text):
			_treasures.append({"name": name_text, "facts": CardValue.facts(CardRegistry.get_card(name_text)),
				"treasure": name_text in held})
	return _treasures


## Forget the cards (the card pool changed, a test).
static func forget() -> void:
	_treasures.clear()
	_read_at = -1
