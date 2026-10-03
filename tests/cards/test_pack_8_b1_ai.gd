extends GameTest
## Pack 8, batch B1: the phasing and hidden-zone-choice cards in AI hands.
## Two AI seats play a board and hands of them without tripping (every
## phased-out permanent parked once, off every battlefield list), and every
## card-authored hint is FAIR (CONTRIBUTING rule 8): substituting the other
## seat's hidden hand and both libraries' order changes no hint, while a
## public change does.

const PHASING := ["Teferi's Drake", "Teferi's Imp", "Warping Wurm", "Shimmering Efreet",
	"Ertai's Familiar", "Mist Dragon", "Rainbow Efreet", "Crystal Golem", "Vodalian Illusionist",
	"Dream Fighter", "Taniwha", "Teferi's Isle"]
const ENCHANTMENTS := ["Equipoise", "Teferi's Veil", "Spatial Binding"]
const SPELLS := ["Reality Ripple", "Sapphire Charm", "Vision Charm", "Time and Tide",
	"Enlightened Tutor", "Mystical Tutor", "Worldly Tutor", "Vampiric Tutor", "Rampant Growth",
	"Tithe", "Three Wishes", "Illicit Auction", "Forbidden Ritual", "Tariff", "Natural Balance"]
const LANDS := ["Plains", "Island", "Swamp", "Mountain", "Forest"]

const VIS_CHOICES := preload("res://cards/sets/vis/_choices.gd")
const VIS_PHASING := preload("res://cards/sets/vis/_phasing.gd")
const MIR_CHOICES := preload("res://cards/sets/mir/_choices.gd")
const MIR_PHASING := preload("res://cards/sets/mir/_phasing.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _seat(pid: int, bodies: Array) -> void:
	for land in LANDS:
		for n in 3: put_battlefield(pid, land)
	put_battlefield(pid, "Sol Ring")
	for card_name in bodies: put_battlefield(pid, card_name)
	for card_name in SPELLS: give_hand(pid, card_name)


## Every phased-out permanent parked exactly once, off every battlefield list.
func _parking_problems() -> Array[String]:
	var out: Array[String] = []
	for p in g.players:
		for inst in p.battlefield:
			if inst.phased_out:
				out.append("%s is on a battlefield list while phased out" % inst)
		for inst in p.phased_out:
			if not inst.phased_out or inst.zone != Mtg.Zone.BATTLEFIELD:
				out.append("%s is parked but not phased out" % inst)
			if g.all_battlefield().has(inst):
				out.append("%s is parked AND on the battlefield" % inst)
	return out


func test_two_ai_seats_play_the_batch_without_tripping() -> void:
	var a := AiPlayer.new(0, AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(0, a)
	g.set_agent(1, b)
	_seat(0, PHASING + ENCHANTMENTS.slice(0, 2))
	_seat(1, PHASING.slice(0, 6) + ["Teferi's Realm", "Katabatic Winds", "Shimmer"])
	var problems: Array[String] = []
	var guard := 0
	while g.turn_number < 10 and not g.game_over and guard < 4000:
		if a.act(g) == "" and b.act(g) == "":
			break
		guard += 1
		if problems.is_empty():
			problems = _parking_problems()
	assert_true(g.turn_number >= 10 or g.game_over,
		"the duel moved on (turn %d, %d actions)" % [g.turn_number, guard])
	assert_eq(problems, [] as Array[String])


# ------------------------------------------------------------ fair hints --

## Swap the other seat's hidden hand for different cards of the same count
## and reverse both libraries — nothing a fair hint may read.
func _substitute_hidden(seat: int) -> void:
	var hand := g.players[seat].hand.duplicate()
	for card in hand:
		g.discard_cards(seat, [card])
	for n in hand.size():
		give_hand(seat, "Forest" if n % 2 == 0 else "Shivan Dragon")
	for p in g.players:
		p.library.reverse()


func _hints() -> Array:
	var angel := g.players[1].creatures()[0]
	return [
		VIS_CHOICES._repeat_hint(g, 0, 1),
		VIS_CHOICES._toll_hint(g, 1, [0, 1, 2] as Array[int]),
		VIS_PHASING._realm_hint(g, 0),
		VIS_PHASING._realm_hint(g, 1),
		MIR_CHOICES.Auction._hint(g, 0, angel, 3),
		MIR_CHOICES.Auction._hint(g, 1, angel, 3),
		MIR_PHASING._sapphire_mode(g, 0),
		VIS_PHASING._vision_mode(g, 0),
		MIR_PHASING.H.best_first(g.players[1].battlefield).map(func(i: CardInstance) -> int: return i.id),
	]


func test_card_hints_ignore_the_hidden_hand_and_library_order() -> void:
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Island")
	put_battlefield(0, "Grizzly Bears")
	for name in ["Lightning Bolt", "Hill Giant", "Holy Strength"]:
		give_hand(1, name)
		give_hand(0, name)
	var before := _hints()
	_substitute_hidden(1)
	_substitute_hidden(0)
	assert_eq(_hints(), before, "no hint read a hidden card or a library's order")


func test_card_hints_follow_a_public_change() -> void:
	put_battlefield(1, "Forest")
	assert_eq(VIS_PHASING._realm_hint(g, 0), 2, "Teferi's Realm: lands cost P0 nothing")
	for n in 2: put_battlefield(1, "Hill Giant")
	assert_eq(VIS_PHASING._realm_hint(g, 0), 1, "visible Giants make creatures the choice")
	for n in 2: put_battlefield(0, "Grizzly Bears")
	assert_eq(VIS_PHASING._realm_hint(g, 0), 2, "unless it costs P0 its own creatures for two turns")
	var angel := put_battlefield(1, "Serra Angel")
	assert_eq(MIR_CHOICES.Auction._hint(g, 0, angel, 3), 1, "worth topping a bid of 3")
	assert_eq(MIR_CHOICES.Auction._hint(g, 0, angel, 9), 0, "not a bid of 9 for a 4/4")
