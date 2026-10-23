class_name Quests
extends RefCounted
## THE TOWNS' QUESTS (the owner, 2026-10-23: part A of the world's missing
## pieces) — 1.3's quest generator in `RunTownServicesMenu` (visitLocation.c
## 1689–1772), the offer in `VisitTownWiseman` (859–990), the reward in
## `VisitTownSlot` (4428–4590) and the deadline in
## `DrawAdventureQuestStatusPanel` (adventureWorldUi.c 1642), in the words
## of `@CITYWISEMAN`, `@VISIT` and `@QUESTSTATUS`.
##
## THE QUEST RECORD ([member AdventurePlayer.quest], `{}` for none): `type`
## — 0 a letter whose reward is a mana link, 2 a letter for an amulet, 1 a
## card of a colour and class, below 0 a creature to defeat (below −100
## defeated, the reward waiting) —, `destination` (a site slot), `giver`,
## `color` (1 black … 5 white), `data` (the quarter the destination lay in
## when the hero set out, 0 north … 3 west; −1 once the hero has turned
## off it) and `deadline` (on the quest clock).
##
## A NEW QUEST is drawn on every visit to a town other than the last one
## ([member AdventurePlayer.last_town]), kept as the town's offer
## ([member AdventurePlayer.quest_offer]):
##  - a village gives a letter two times in three (always when it is
##    linked): its destination a town or city no wizard holds and not
##    linked, 8 to 16 tiles away (the reach grows a tile every 16 of up to
##    1000 tries); a letter for a link or for an amulet, half and half — a
##    link only when the hero holds an amulet of its colour; and sometimes,
##    when a colour drawn does not go with the town's, a card of that colour
##    instead, its class by the destination (`slot & 3`: land, creature,
##    enchantment, sorcery);
##  - towns and cities, and the other third of the villages, ask for a
##    creature defeated — those quests come with the creatures and their
##    duels; until then no quest is offered there.
##  - "Begin a Quest" stands in the town's choices while no quest is under
##    way, an offer waits, and (difficulty + 3) · 16 steps of the quest
##    clock have passed since the town last gave one.
##  - A town whose quest the hero failed ([TownStatus.NO_QUESTS]) keeps no
##    offer and offers none: its wise man turns the hero away whatever is
##    asked of him (`VisitTownWiseman` reads the bit first, visitLocation.c
##    876). [Ours: 1997 still drew the offer there and its button still read
##    "Begin a Quest", to be refused on the click; ours draws the dice the
##    same and shows the wise man's button, who refuses the same.]
## ACCEPTED: the deadline is the quest's units · 2 − 1 steps on (a letter
## 32 units, "4 days"; a card 40, "5 days"), the town remembers when it gave
## it, the destination and the giver are put on the map, and the offer is
## spent [ours: 1997 kept it — no quest could be begun while one ran, and
## the next town visited, the destination, drew a new one]. COMPLETED on
## arriving at the destination: a letter makes a mana link there (or gives
## the amulet); a card is taken — one of the colour and class — for an
## amulet and a link. FAILED when the clock reaches the deadline: "The
## people of %s are sorry their quest was not completed.", and the giver's
## wise man turns the hero away for good ([TownStatus.NO_QUESTS]).
## [Ours: the giver is kept with the quest (1997 lost it in a save); a card
## quest takes a matching card the hero's decks do not hold before one they
## do (1997 took the first in its sort order, unasked); 1997's blank colour
## word for white is mended.]

const LETTER_LINK := 0
const CARD := 1
const LETTER_AMULET := 2
## A defeated creature's quest type is below this.
const DEFEATED := -100
## The quests' time units (a day is 8 of them, 16 steps of the clock).
const UNITS := {LETTER_LINK: 32, LETTER_AMULET: 32, CARD: 40}
const CREATURE_UNITS := 24
## A town gives a new quest this many steps of the clock, per difficulty
## step, after the last.
const QUEST_WAIT := 16
## Before the first quest: long ago.
const NEVER := -1000
## The card classes of a card quest, by the destination's `slot & 3`
## (1997 type bits), and their names (`@CARDCLASSNAMES`).
const CLASS_BITS: Array[int] = [CardValue.LAND, CardValue.CREATURE, CardValue.ENCHANTMENT, CardValue.SORCERY]
const CLASS_NAMES: Array[String] = ["Land", "Creature", "Enchantment", "Sorcery"]
const COLOR_WORDS: Array[String] = ["black", "blue", "green", "red", "white"]
## The destination search.
const TRIES := 1000
const NEAREST := 8
const FARTHEST := 16


# ------------------------------------------------------------ the offer --

## THE HERO ARRIVES at town [param slot], another than the last: its quest
## is drawn ([member AdventurePlayer.quest_offer]) — the town's colour this
## visit is [CardTrade]'s ([method CardTrade.arrive]). The dice draw as
## 1997's did, a delivery's draws even when no destination is found, and a
## town that refuses quests ([TownStatus.refuses_quests]) keeps none.
static func arrive(player: AdventurePlayer, slot: int) -> void:
	var world := player.world
	player.quest_offer = {}
	var site_type := int(world.sites[slot]["type"])
	var dice := MsvcRandom.new(player.dice)
	var delivery := (dice.below(3) != 0 or TownStatus.linked(world, slot)) and site_type == ShandalarWorld.VILLAGE
	if delivery:
		var destination := _destination(world, slot, dice)
		var kind := LETTER_LINK if dice.below(2) != 0 else LETTER_AMULET
		if destination >= 0:
			var favoured := CardTrade.favoured(player, slot)
			var color := 0
			var scan := dice.below(5) + 1
			if favoured >= 1 and not CardValue.goes_with(1 << scan, 1 << favoured, 3) and dice.below(2) != 0:
				kind = CARD
				color = scan
			if kind != CARD:
				color = _color_on(world, destination, dice)
				if kind == LETTER_LINK and int(player.amulets.get(COLOR_WORDS[color - 1], 0)) <= 0:
					kind = LETTER_AMULET
			player.quest_offer = {"type": kind, "destination": destination, "color": color, "at": slot}
	# The creature quests (towns, cities, a third of the villages) come with
	# the creatures and their duels.
	player.dice = dice.state
	if TownStatus.refuses_quests(world, slot):
		player.quest_offer = {}


## A destination for a delivery from site [param giver]: a town or city
## neither linked nor held by a wizard, at least [constant NEAREST] tiles
## away and at most [constant FARTHEST] and a tile more every 16 tries; −1
## after [constant TRIES].
static func _destination(world: ShandalarWorld, giver: int, dice: MsvcRandom) -> int:
	var from := Vector2i(int(world.sites[giver]["x"]), int(world.sites[giver]["y"]))
	for t in range(1, TRIES + 1):
		var slot := dice.below(world.sites.size())
		var kind := int(world.sites[slot]["type"])
		if kind != ShandalarWorld.TOWN and kind != ShandalarWorld.CITY:
			continue
		if TownStatus.linked(world, slot) or TownStatus.ruled(world, slot):
			continue
		var distance := WorldGenerator.distance(int(world.sites[slot]["x"]) - from.x,
			int(world.sites[slot]["y"]) - from.y)
		if distance >= NEAREST and distance <= t / 16 + FARTHEST:
			return slot
	return -1


## A colour of the land site [param slot] stands on, drawn until one is
## (1 black … 5 white).
static func _color_on(world: ShandalarWorld, slot: int, dice: MsvcRandom) -> int:
	var mask := CardShop.town_colors(world, slot)
	if mask & 0x3E == 0:
		return 1
	while true:
		var color := dice.below(5) + 1
		if mask & (1 << color) != 0:
			return color
	return 1


## Whether town [param slot] offers its quest now ("Begin a Quest"): no
## quest under way, an offer drawn in this town (to a site of the world),
## the town's wait since its last quest over, and not a town that turns
## the hero away.
static func offered(player: AdventurePlayer, slot: int) -> bool:
	var offer := player.quest_offer
	if has_quest(player) or offer.is_empty() or TownStatus.refuses_quests(player.world, slot):
		return false
	return int(offer.get("at", -1)) == slot and is_site(player.world, int(offer.get("destination", -1))) \
		and _waited(player, slot)


static func _waited(player: AdventurePlayer, slot: int) -> bool:
	var given := int(player.town_quests.get(str(slot), NEVER))
	return player.quest_timer - given > (clampi(player.difficulty, 0, 3) + 3) * QUEST_WAIT


## The town's offer, said as its wise man says it (`@CITYWISEMAN` 1–5), a
## line each; empty for none.
static func offer_words(player: AdventurePlayer) -> PackedStringArray:
	var lines := PackedStringArray()
	var offer := player.quest_offer
	if offer.is_empty():
		return lines
	var world := player.world
	var destination := int(offer["destination"])
	var town := WorldNames.site_name(world, destination)
	var way := WorldNames.direction(player.tile(), site_tile(world, destination))
	var color := int(offer.get("color", 1))
	match int(offer["type"]):
		LETTER_LINK:
			lines.append("Take this message %s to my brother, the keeper of %s." % [way, town])
			lines.append("He will reward you with a mana link.")
		LETTER_AMULET:
			lines.append("Take this message %s to my brother, the keeper of %s." % [way, town])
			lines.append("He will reward you with a %s." % amulet_name(color))
		CARD:
			lines.append("Take a %s %s to the keeper of %s." % [spell_name(color, destination), way, town])
			lines.append("He will give you a mana link and 1 %s." % amulet_name(color))
	return lines


## ACCEPT town [param giver]'s offer: the quest under way, its deadline
## set, the destination and the giver on the map, the offer spent. The words
## for the screen ("You have 4 days to complete the quest."), or "" when
## the town offers none now ([method offered]).
static func accept(player: AdventurePlayer, giver: int) -> String:
	if not offered(player, giver):
		return ""
	var offer := player.quest_offer
	player.quest_offer = {}
	var kind := int(offer["type"])
	var units := int(UNITS.get(kind, CREATURE_UNITS))
	var destination := int(offer["destination"])
	player.quest = {"type": kind, "destination": destination, "giver": giver,
		"color": int(offer.get("color", 1)),
		"data": WorldNames.quadrant(site_tile(player.world, destination).x - player.tile().x,
			site_tile(player.world, destination).y - player.tile().y),
		"deadline": player.quest_timer + units * 2 - 1}
	player.town_quests[str(giver)] = player.quest_timer
	for slot in [destination, giver]:
		var tile := site_tile(player.world, slot)
		player.world.explore_around(tile)
	player.log_event("quest_begun", "Quest for %s" % WorldNames.site_name(player.world, giver))
	return "You have %d days to complete the quest." % (units / 8)


# ---------------------------------------------------------- the quest --

## Whether a quest is under way.
static func has_quest(player: AdventurePlayer) -> bool:
	return not player.quest.is_empty() and int(player.quest.get("destination", -1)) >= 0


## THE HERO ARRIVES AT TOWN [param slot]: the quest whose destination it is
## completed — the words for the town's pane (`@VISIT` 16–20) and the sound
## (`mana_link`, `reward` or ""), or `{}` when nothing was completed.
static func complete_at(player: AdventurePlayer, slot: int) -> Dictionary:
	if not has_quest(player) or int(player.quest["destination"]) != slot:
		return {}
	var world := player.world
	var color := clampi(int(player.quest.get("color", 1)), 1, 5)
	var hue := COLOR_WORDS[color - 1]
	var lines := PackedStringArray()
	var sound := ""
	match int(player.quest["type"]):
		LETTER_LINK:
			lines.append("The keeper is pleased to receive his brother's letter.")
			lines.append("You create a mana link here.")
			TownStatus.put(world, slot, TownStatus.LINKED)
			sound = "sfx_mana_link"
		LETTER_AMULET:
			lines.append("The keeper is pleased to receive his brother's letter.")
			lines.append("You are rewarded with a fine %s." % amulet_name(color))
			player.amulets[hue] = int(player.amulets.get(hue, 0)) + 1
			sound = "sfx_reward"
		CARD:
			var at := card_for_quest(player)
			if at < 0:
				return {}
			var card_name := String(player.cards[at]["card"])
			player.cards.remove_at(at)
			player.amulets[hue] = int(player.amulets.get(hue, 0)) + 1
			TownStatus.put(world, slot, TownStatus.LINKED)
			lines.append("The people are pleased to receive the %s spell." % card_name)
			lines.append("You are rewarded with a fine %s and a mana link." % amulet_name(color))
		_:
			return {}
	player.quest = {}
	return {"lines": lines, "sound": sound}


## The card a card quest would take, as a place in the hero's cards, or −1:
## one of the quest's colour and class, a card no deck holds before one a
## deck does [ours].
static func card_for_quest(player: AdventurePlayer) -> int:
	if not has_quest(player) or int(player.quest["type"]) != CARD:
		return -1
	var color_bit := 1 << clampi(int(player.quest.get("color", 1)), 1, 5)
	var class_bit := card_class(int(player.quest["destination"]))
	var in_a_deck := -1
	for i in player.cards.size():
		var entry := player.cards[i] as Dictionary
		var card_name := String(entry.get("card", ""))
		if not CardRegistry.has_card(card_name):
			continue
		var f := CardValue.facts(CardRegistry.get_card(card_name))
		if int(f.get("color", 0)) & color_bit == 0 or int(f.get("type", 0)) & class_bit == 0:
			continue
		if (entry.get("decks", []) as Array).is_empty():
			return i
		if in_a_deck < 0:
			in_a_deck = i
	return in_a_deck


## THE QUEST'S TIME: when the clock has reached the deadline the quest is
## lost — the giver's wise man turns the hero away for good, the journal
## says so — and the 1997 words for the screen; "" while it still runs.
static func check_deadline(player: AdventurePlayer) -> String:
	if not has_quest(player):
		return ""
	if int(player.quest.get("deadline", 0)) > player.quest_timer:
		return ""
	var giver := int(player.quest.get("giver", -1))
	var town := WorldNames.site_name(player.world, giver)
	TownStatus.put(player.world, giver, TownStatus.NO_QUESTS)
	player.log_event("quest", "Quest failed for %s" % town, {"done": false})
	player.quest = {}
	return "The people of %s are sorry their quest was not completed." % town if town != "" \
		else "Your quest was not completed in time."


## The hero has walked: once they have turned off the quarter they set out
## in, the panel says what to do there, no longer which way (`data` −1).
static func note_heading(player: AdventurePlayer) -> void:
	if not has_quest(player) or int(player.quest.get("data", -1)) < 0:
		return
	var there := site_tile(player.world, int(player.quest["destination"]))
	var way := WorldNames.quadrant(there.x - player.tile().x, there.y - player.tile().y)
	if way != int(player.quest["data"]):
		player.quest["data"] = -1


# ------------------------------------------------------------ the words --

## A card quest's class bit, by its destination (`1 << (slot & 3)`).
static func card_class(destination: int) -> int:
	return CLASS_BITS[destination & 3]


## "black Creature spell" (`@SPELLNAMES`), for colour [param color] and
## destination [param destination].
static func spell_name(color: int, destination: int) -> String:
	return "%s %s spell" % [COLOR_WORDS[clampi(color, 1, 5) - 1], CLASS_NAMES[destination & 3]]


## "black amulet" (`@AMULETNAMES`).
static func amulet_name(color: int) -> String:
	return "%s amulet" % COLOR_WORDS[clampi(color, 1, 5) - 1]


## Whether [param slot] is one of the world's sites — a quest read from a
## save may name one that is not.
static func is_site(world: ShandalarWorld, slot: int) -> bool:
	return world != null and slot >= 0 and slot < world.sites.size()


## Site [param slot]'s tile ((0, 0) for no such site).
static func site_tile(world: ShandalarWorld, slot: int) -> Vector2i:
	if not is_site(world, slot):
		return Vector2i.ZERO
	return Vector2i(int(world.sites[slot]["x"]), int(world.sites[slot]["y"]))
