class_name WiseMan
extends RefCounted
## THE TOWNS' WISE MEN (the owner, 2026-10-23: part A of the world's missing
## pieces; *"Enable them"* — all six gifts) — 1.3's `VisitTownWiseman`
## (visitLocation.c 859–990) and `RunWisemanAdviceSequence` (005318f5),
## in the words of `@CITYWISEMAN` and `@WISEMAN`; the tales and the news are
## the player's own `Advblocks.txt` (`adventure_wise_words.json`, imported
## by `tools/import_original.py`).
##
## A town whose quest was failed turns the hero away for good ([TownStatus.
## NO_QUESTS]). Otherwise, on a first talk in a town other than the last one
## visited:
##  - one time in five, A TALE of long ago (twelve, in pages);
##  - else one in five, NEWS: a wizard not yet beaten, his life in his
##    stronghold and the towns he holds; two towns the hero has links with;
##    or a World Magic not yet owned and the town that sells it;
##  - else, two times in five while a quest is under way, A REMINDER of it
##    ("If you seek the mana link, travel North to …"), and otherwise
##  - A GIFT, chosen by where the town stands, one of six ([constant
##    GIFTS]): a tale; a clue to a castle or dungeon (a gift of lives when
##    none is left); two extra lives in the next duel (25 food when a gift
##    for it already waits); a look at the deck of any creature of the
##    town's colour; a companion of that colour in play in the next duel
##    (else the look at a deck); three amulets of that colour fashioned into
##    a copy of any card the hero owns (else the lives).
## Another talk in the same town says the same again; after a gift, tales.
## [Ours: 1997 could only give four of the six gifts — its pick, `(x % 2)
## + (y % 3)`, never reaches 4 or 5 — and the owner ruled all six be given:
## each of the six places a town's tile can have (x even or odd, y by
## threes) gives one. The copy takes the three amulets only once a card is
## picked, and is offered only to a hero who holds them (1997 took them
## first, into debt). The news names a wizard and a World Magic fairly
## (1997's picks were off by one), gives the wizard's real life in his
## castle and the towns he truly holds (1997 counted another colour's), and
## falls back to a tale when there are not two linked towns to name.]

## The gifts, by the town's tile: GIFTS[x % 2][y % 3].
const TALE := 0
const CLUE := 1
const LIVES := 2
const DECK := 3
const COMPANION := 4
const COPY := 5
const GIFTS: Array[Array] = [[TALE, CLUE, LIVES], [COMPANION, COPY, DECK]]
## The companion cards, two by the town's colour, black … white
## (`g_wiseman_duel_reward_card_csvids`).
const COMPANIONS: Array[Array] = [["Carrion Ants", "Khabal Ghoul"],
	["Prodigal Sorcerer", "Merchant Ship"], ["Verduran Enchantress", "Wyluli Wolf"],
	["Keldon Warlord", "Atog"], ["Samite Healer", "Benalish Hero"]]
const COPY_COST := 3
const FOOD_GIFT := 25
const LIVES_GIFT := 2
## The stages a talk replays (`g_wiseman_advice_stage`).
const STAGE_TALE := 0
const STAGE_NEWS := 1
const STAGE_GIFT := 2

## `@CITYWISEMAN` 0 and `@WISEMAN` 0–17.
const REFUSAL := "You failed to complete your last quest for this village.\n\nThe people have no new quest for you."
const APPLAUSE := "The wise man says:\n“The people applaud your brave struggle to free Shandalar from the tyranny of the Five Wizards.\n\n"
const GIFT_WORDS := {
	TALE: "To assist you I shall tell you a tale of long long ago.”",
	CLUE: "To assist you I shall tell you of the dungeons which hold valuable spells.”",
	LIVES: "To assist you I shall strengthen you with two extra lives in your next duel.”",
	DECK: "To assist you I shall reveal to you the secret deck of any %s creature.”",
	COMPANION: "To assist you I shall provide you a %s companion in your next duel.”",
	COPY: "To assist you I shall fashion 3 %s into a duplicate of any spell you possess.”",
}
const FOOD_WORDS := "To assist you I shall fortify you with extra food for your journeys.”"
const COLOR_WORDS: Array[String] = ["black", "blue", "green", "red", "white"]

static var _words: Dictionary = {}
static var _read := false


## The imported tales and news (`{city: [4], tales: [12 × pages]}`), or {}.
static func words() -> Dictionary:
	if not _read:
		_read = true
		_words = GameSkin.metadata("adventure_wise_words")
	return _words


static func forget() -> void:
	_words = {}
	_read = false


# ------------------------------------------------------------ the talk --

## WHAT THE WISE MAN OF TOWN [param slot] SAYS: `{pages, then, color}` —
## the pages to show one after another; `then` what the hero chooses next
## (`deck`: a creature of `color` whose deck to see; `copy`: a card to
## copy for three `color` amulets; "" nothing); gifts already given.
static func speak(player: AdventurePlayer, slot: int) -> Dictionary:
	var talk := {"pages": PackedStringArray(), "then": "", "color": 0}
	if TownStatus.refuses_quests(player.world, slot):
		talk["pages"].append(REFUSAL)
		return talk
	var fresh := player.last_town != slot
	var state := player.wise_man
	var dice := MsvcRandom.new(player.dice)
	var stage := int(state.get("stage", STAGE_TALE))
	if fresh:
		if dice.below(5) == 0:
			stage = STAGE_TALE
			state["tale"] = dice.rand() % 12
		elif dice.below(5) == 0:
			stage = STAGE_NEWS
			state["news"] = _news(player, dice)
		else:
			stage = STAGE_GIFT
			state["remind"] = dice.below(5) < 2
	else:
		dice.below(5)
	player.dice = dice.state
	match stage:
		STAGE_TALE:
			talk["pages"].append_array(_tale(player))
		STAGE_NEWS:
			var news := String(state.get("news", ""))
			if news == "":
				talk["pages"].append_array(_tale(player))
				stage = STAGE_TALE
			else:
				talk["pages"].append(news)
		STAGE_GIFT:
			var reminded := reminder(player) if bool(state.get("remind", false)) and Quests.has_quest(player) else ""
			if reminded != "":
				talk["pages"].append(reminded)
			else:
				talk.merge(_gift(player, slot), true)
				stage = STAGE_TALE
	state["stage"] = stage
	player.wise_man = state
	player.last_town = slot
	return talk


## The tale last told (a new one when there is none): its pages.
static func _tale(player: AdventurePlayer) -> PackedStringArray:
	var tales: Array = words().get("tales", [])
	var pages := PackedStringArray()
	if tales.is_empty():
		pages.append("The wise man speaks of Shandalar long ago, when magic was free to all.")
		return pages
	var index := int(player.wise_man.get("tale", -1))
	if index < 0 or index >= tales.size():
		var dice := MsvcRandom.new(player.dice)
		index = dice.rand() % tales.size()
		player.dice = dice.state
		player.wise_man["tale"] = index
	for page in tales[index]:
		pages.append(String(page))
	return pages


## THE NEWS (one of three, drawn with [param dice]), in the imported words
## where there are some: "" when the news drawn has nothing to tell.
static func _news(player: AdventurePlayer, dice: MsvcRandom) -> String:
	var city: Array = words().get("city", [])
	var block := dice.rand() % 3
	match block:
		0:
			var standing: Array[int] = []
			for i in 5:
				if not AdventurePlayer.COLORS[i] in player.defeated_wizards:
					standing.append(i + 1)
			if standing.is_empty():
				return ""
			var wizard := standing[dice.below(standing.size())]
			var female := wizard == 2 or wizard == 4
			var text := String(city[3 if female else 0]) if city.size() >= 4 else \
				"I see you have not yet defeated the %1 in his Castle.\nHe has %2!d! life in his stronghold\nand controls %3!d! mana domes."
			return fill(text, [WorldNames.WIZARDS[wizard - 1], castle_life(player, wizard),
				WorldStatus.taps(player)[wizard - 1]])
		1:
			var linked: Array[int] = []
			for site in player.world.sites.size():
				if TownStatus.linked(player.world, site):
					linked.append(site)
			if linked.size() < 2:
				return ""
			var a := linked[dice.below(linked.size())]
			var b := a
			while b == a:
				b = linked[dice.below(linked.size())]
			var text := String(city[1]) if city.size() >= 4 else "Two of the cities with which you have links are %s and %s."
			return fill(text, [WorldNames.site_name(player.world, a), WorldNames.site_name(player.world, b)])
		_:
			var open: Array[int] = []
			for i in AdventurePlayer.WORLD_MAGICS.size():
				if WorldMagicShop.seller(player.world, i) > 0 and not player.owns(AdventurePlayer.WORLD_MAGICS[i]):
					open.append(i)
			if open.is_empty():
				return ""
			var magic := open[dice.below(open.size())]
			var text := String(city[2]) if city.size() >= 4 else "The World Magic %1 may be found in %2."
			return fill(text, [AdventurePlayer.WORLD_MAGICS[magic],
				WorldNames.site_name(player.world, WorldMagicShop.seller(player.world, magic))])


## A wizard's life in his stronghold: twenty, five a difficulty step and ten
## more, less one for each of the hero's wins against his colour, and a
## difficulty step for each town he holds — never under 20 and five a step
## (1.3 `duel.c` 2241–2270).
static func castle_life(player: AdventurePlayer, wizard: int) -> int:
	var d := clampi(player.difficulty, 0, 3)
	var wins := 0
	for win in player.duel_victories:
		var hue: Variant = (win as Dictionary).get("color", -1) if win is Dictionary else -1
		if hue is String:
			hue = AdventurePlayer.COLORS.find(String(hue)) + 1
		if int(hue) == wizard:
			wins += 1
	var towns: int = WorldStatus.taps(player)[wizard - 1]
	return maxi(20 + 5 * d + 10 - wins + towns * d, 5 * d + 20)


## A REMINDER of the quest under way (`@WISEMAN` 0–2), and the panel's way
## to it shown again; "" when the quest names no site of the world (a save's
## — then the wise man gives his gift instead).
static func reminder(player: AdventurePlayer) -> String:
	var quest := player.quest
	var destination := int(quest.get("destination", -1))
	if not Quests.is_site(player.world, destination):
		return ""
	var town := WorldNames.site_name(player.world, destination)
	var there := Quests.site_tile(player.world, destination)
	var way := WorldNames.quadrant(there.x - player.tile().x, there.y - player.tile().y)
	var color := int(quest.get("color", 1))
	match int(quest.get("type", 0)):
		Quests.LETTER_LINK:
			quest["data"] = way
			return "If you seek the mana link, travel %s to %s." % [WorldNames.DIRECTIONS[way], town]
		Quests.CARD:
			if Quests.card_for_quest(player) < 0:
				return "I see that the people of %s have asked for a %s." % [town, Quests.spell_name(color, destination)]
	quest["data"] = way
	return "If you seek the %s, travel %s to %s." % [Quests.amulet_name(color), WorldNames.DIRECTIONS[way], town]


# ------------------------------------------------------------ the gifts --

## The gift of town [param slot] ([constant GIFTS] by its tile), given now
## where it needs no choice: `{pages, then, color}`.
static func _gift(player: AdventurePlayer, slot: int) -> Dictionary:
	var site: Dictionary = player.world.sites[slot]
	var gift: int = GIFTS[int(site["x"]) % 2][int(site["y"]) % 3]
	var color := CardTrade.favoured(player, slot)
	if color == 0:
		color = _land_color(player, slot)
	return give(player, gift, color)


## GIFT [param gift] in colour [param color] (1–5): the pages; the effects
## that need no choice made.
static func give(player: AdventurePlayer, gift: int, color: int) -> Dictionary:
	var talk := {"pages": PackedStringArray(), "then": "", "color": color}
	var hue := COLOR_WORDS[clampi(color, 1, 5) - 1]
	match gift:
		TALE:
			talk["pages"].append(APPLAUSE + String(GIFT_WORDS[TALE]))
			player.wise_man["tale"] = -1
			talk["pages"].append_array(_tale(player))
		CLUE:
			var told := WorldClues.reveal_for_hint(player)
			if told < 0:
				return give(player, LIVES, color)
			var lines := PackedStringArray([APPLAUSE + String(GIFT_WORDS[CLUE]), "", WorldClues.title(told)])
			lines.append_array(WorldClues.lines(player.world, told))
			talk["pages"].append("\n".join(lines))
		LIVES:
			if not player.duel_gift_waiting():
				player.next_duel_life = LIVES_GIFT
				talk["pages"].append(APPLAUSE + String(GIFT_WORDS[LIVES]))
			else:
				player.food += FOOD_GIFT
				talk["pages"].append(APPLAUSE + FOOD_WORDS)
		DECK:
			talk["pages"].append(APPLAUSE + String(GIFT_WORDS[DECK]) % hue)
			talk["then"] = "deck"
		COMPANION:
			if player.duel_gift_waiting():
				return give(player, DECK, color)
			var dice := MsvcRandom.new(player.dice)
			var companion: String = COMPANIONS[clampi(color, 1, 5) - 1][dice.below(2)]
			player.dice = dice.state
			player.next_duel_card = companion
			talk["pages"].append(APPLAUSE + String(GIFT_WORDS[COMPANION]) % companion)
		COPY:
			if int(player.amulets.get(hue, 0)) < COPY_COST:
				return give(player, LIVES, color)
			talk["pages"].append(APPLAUSE + String(GIFT_WORDS[COPY]) % ("%s amulets" % hue))
			talk["then"] = "copy"
	return talk


## THE COPY made: [param card_name] once more in the hero's cards (in no
## deck), for three amulets of [param color]. False when it cannot be.
static func copy(player: AdventurePlayer, card_name: String, color: int) -> bool:
	var hue := COLOR_WORDS[clampi(color, 1, 5) - 1]
	if int(player.amulets.get(hue, 0)) < COPY_COST or not CardRegistry.has_card(card_name):
		return false
	player.amulets[hue] = int(player.amulets[hue]) - COPY_COST
	player.cards.append({"card": card_name, "decks": []})
	return true


## A colour of the land site [param slot] stands on, the first (1–5).
static func _land_color(player: AdventurePlayer, slot: int) -> int:
	var mask := CardShop.town_colors(player.world, slot)
	for color in range(1, 6):
		if mask & (1 << color) != 0:
			return color
	return 1


## [param text] with its inserts filled from [param values]: `%1`, `%2!d!`
## (FormatMessage's) by number, then each `%s` in turn.
static func fill(text: String, values: Array) -> String:
	var out := text
	for i in values.size():
		out = out.replace("%%%d!d!" % (i + 1), str(values[i])).replace("%%%d" % (i + 1), str(values[i]))
	for value in values:
		if not out.contains("%s"):
			break
		out = _replace_first(out, "%s", str(value))
	return out


static func _replace_first(text: String, what: String, with: String) -> String:
	var at := text.find(what)
	return text if at < 0 else text.left(at) + with + text.substr(at + what.length())
