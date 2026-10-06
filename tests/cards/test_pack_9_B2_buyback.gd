extends GameTest
## Pack 9 (the Tempest block), batch B2: BUYBACK on every buyback spell of
## the block (cards/sets/{tmp,sth,exo}/_buyback.gd) — the lifecycle
## matrix, card by card, and Memory Crystal.
##
## Buyback is an optional ADDITIONAL cost announced with the spell (CR
## 702.27a, 601.2b), carried as a payment row (engine package E2): row 0
## pays the printed cost, row 1 the same spell with buyback. For every card:
## - unpaid, it resolves into its owner's graveyard;
## - paid, it resolves and returns to its owner's HAND (CR 608.2n);
## - paid and COUNTERED, it never resolved: graveyard;
## - paid and FIZZLED (every target illegal, CR 608.2b): graveyard;
## - a COPY (Fork) is not a card and goes nowhere (CR 707.10a); the
##   original returns when it resolves, and goes to the graveyard when the
##   copy took its only target first.
## The paid and unpaid rows are run under all three rules presets.

const BUYBACK := ["Anoint", "Capsize", "Corpse Dance", "Disturbed Burial", "Elvish Fury",
	"Evincar's Justice", "Imps' Taunt", "Invulnerability", "Searing Touch", "Whim of Volrath",
	"Whispers of the Muse", "Worthy Cause",
	"Brush with Death", "Change of Heart", "Constant Mists", "Fanning the Flames", "Lab Rats",
	"Mind Games", "Mind Peel", "Seething Anger", "Verdant Touch",
	"Allay", "Flowstone Flood", "Forbid", "Pegasus Stampede", "Reaping the Rewards",
	"Shattering Pulse", "Slaughter"]
## Spells with no target, or only a player one: nothing to make illegal.
const NO_FIZZLE := ["Corpse Dance", "Evincar's Justice", "Invulnerability", "Whispers of the Muse",
	"Worthy Cause", "Lab Rats", "Constant Mists", "Pegasus Stampede", "Reaping the Rewards",
	"Brush with Death", "Mind Peel"]
## A Fork copy that keeps the original's only target and removes it (or
## counters it) resolves first and leaves the original without a legal
## target: the original fizzles into the graveyard, buyback paid or not.
const COPY_TAKES_THE_TARGET := ["Capsize", "Disturbed Burial", "Allay", "Shattering Pulse",
	"Slaughter", "Flowstone Flood", "Forbid"]
const PRESETS := ["modern", "modern_mana_burn", "fifth"]


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


## A fresh game under [param preset], P0 in its first main phase.
func _fresh(preset := "modern") -> void:
	before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


## Put EXACTLY the mana the row costs into [param pid]'s pool (coloured
## pips by colour, the rest colourless) — nothing floats to burn.
func _pay(pid: int, spell: CardInstance, mode: int, x: int, targets: int) -> void:
	var pay := g.spell_payment(pid, spell.data, x, targets, spell, mode)
	var cost: ManaCost = pay["cost"]
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + int(pay["extra"])
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


## The board each card needs, built for P0 casting it now. Returns
## {targets, x, victim}: victim is what the fizzle takes away.
func _setup(card_name: String) -> Dictionary:
	var out := {"targets": [], "x": 0, "victim": null}
	var victim: CardInstance = null
	match card_name:
		"Anoint", "Elvish Fury", "Seething Anger":
			victim = put_battlefield(0, "Grizzly Bears")
		"Capsize", "Imps' Taunt", "Change of Heart", "Mind Games", "Searing Touch", "Slaughter":
			victim = put_battlefield(1, "Grizzly Bears")
		"Fanning the Flames":
			victim = put_battlefield(1, "Grizzly Bears")
			out["x"] = 2
		"Corpse Dance":
			_to_graveyard(0, "Grizzly Bears")
		"Disturbed Burial":
			victim = _to_graveyard(0, "Grizzly Bears")
		"Whim of Volrath":
			victim = put_battlefield(1, "Forest")
		"Worthy Cause":
			put_battlefield(0, "Hill Giant")
		"Brush with Death", "Mind Peel":
			give_hand(1, "Forest")
			out["targets"] = [TargetRef.player(1)]
		"Constant Mists", "Pegasus Stampede", "Reaping the Rewards":
			put_battlefield(0, "Plains")
		"Verdant Touch":
			victim = put_battlefield(0, "Forest")
		"Allay":
			victim = put_battlefield(1, "Crusade")
		"Shattering Pulse":
			victim = put_battlefield(1, "Icy Manipulator")
		"Flowstone Flood":
			victim = put_battlefield(1, "Mountain")
			give_hand(0, "Forest")
		"Forbid":
			give_hand(0, "Forest")
			give_hand(0, "Island")
			# P1 casts a Bolt at P0 and passes: P0 has priority over it.
			assert_ok(g.pass_priority(0))
			victim = give_hand(1, "Lightning Bolt")
			add_mana(1, Mtg.ManaColor.R)
			assert_ok(g.cast_spell(1, victim, [TargetRef.player(0)]))
			assert_ok(g.pass_priority(1))
			assert_eq(g.priority_player, 0)
	if victim != null:
		out["victim"] = victim
		out["targets"] = [TargetRef.card(victim)]
	return out


## P0 casts [param card_name] with row [param mode] (0 printed, 1 buyback).
func _cast(card_name: String, mode: int) -> Dictionary:
	var s := _setup(card_name)
	var spell := give_hand(0, card_name)
	var targets: Array = s["targets"]
	_pay(0, spell, mode, int(s["x"]), targets.size())
	assert_ok(g.cast_spell(0, spell, targets, int(s["x"]), mode))
	assert_eq(spell.zone, Mtg.Zone.STACK, card_name)
	assert_eq(g.buyback_paid(spell), mode == 1, "%s: the stack knows the row" % card_name)
	s["spell"] = spell
	return s


## Every object named [param card_name] P0 owns, in any zone (a copy that
## leaked into a hand or a graveyard would be counted).
func _copies_of(card_name: String) -> int:
	var n := 0
	for zone in [g.players[0].hand, g.players[0].graveyard, g.players[0].exile, g.players[0].library]:
		for card in zone:
			if card.data.card_name == card_name: n += 1
	for item in g.stack:
		if item.card != null and item.card.data.card_name == card_name: n += 1
	return n


# ------------------------------------------------------------------ the rows --

func test_every_buyback_card_is_claimed_and_carries_one_buyback_row() -> void:
	for card_name in BUYBACK:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_eq(c.modes.size(), 2, "%s: the printed row and the buyback row" % card_name)
		assert_eq(c.buyback_rows(), [1], card_name)
		assert_true(c.payment_option(0).is_empty(), "%s: row 0 pays the printed cost" % card_name)
		assert_string_contains(String(c.modes[1]["label"]), "buyback", card_name)
		assert_eq(c.modes[0]["effects"], c.modes[1]["effects"], "%s: the same spell either way" % card_name)
	var games := CardRegistry.get_card("Mind Games")
	assert_eq(String(games.payment_option(1)["buyback_text"]), "{2}{U}")
	var mists := CardRegistry.get_card("Constant Mists")
	assert_eq(String(mists.payment_option(1)["buyback_text"]), "Sacrifice a land")
	var flood := CardRegistry.get_card("Flowstone Flood")
	assert_eq(int(flood.payment_option(1)["life"]), 3)
	assert_eq(String(flood.payment_option(1)["object_costs"][0]["operation"]), "random_discard")


func test_the_buyback_never_changes_the_mana_value() -> void:
	var expected := {"Capsize": 3, "Whispers of the Muse": 1, "Brush with Death": 3,
		"Fanning the Flames": 2, "Forbid": 3, "Slaughter": 4}
	for card_name in expected:
		var c := CardRegistry.get_card(card_name)
		assert_eq(c.cost.mana_value(), int(expected[card_name]), "%s (CR 118.8d)" % card_name)
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Capsize"), 0, 1).mana_value(), 6, "{1}{U}{U} plus {3}")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Whispers of the Muse"), 0, 1).mana_value(), 6, "{U} plus {5}")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Mind Peel"), 0, 1).mana_value(), 5, "{B} plus {2}{B}{B}")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Fanning the Flames"), 3, 1).mana_value(), 5,
		"{X}{R}{R} plus {3}: the X is paid on top")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Slaughter"), 0, 1).mana_value(), 4, "Pay 4 life is no mana")


# ------------------------------------------------------- the lifecycle matrix --

func test_unpaid_buyback_resolves_into_the_graveyard_under_every_preset() -> void:
	for preset in PRESETS:
		for card_name in BUYBACK:
			_fresh(preset)
			var s := _cast(card_name, 0)
			resolve_stack()
			assert_eq((s["spell"] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "%s/%s: unpaid" % [preset, card_name])


func test_paid_buyback_returns_the_card_to_its_owners_hand_under_every_preset() -> void:
	for preset in PRESETS:
		for card_name in BUYBACK:
			_fresh(preset)
			var s := _cast(card_name, 1)
			resolve_stack()
			var spell: CardInstance = s["spell"]
			assert_eq(spell.zone, Mtg.Zone.HAND, "%s/%s: paid" % [preset, card_name])
			assert_true(g.players[0].hand.has(spell), "%s/%s: in P0's hand" % [preset, card_name])
			assert_false(g.players[0].graveyard.has(spell), "%s/%s" % [preset, card_name])


func test_a_countered_buyback_spell_goes_to_the_graveyard() -> void:
	for preset in ["modern", "fifth"]:
		for card_name in BUYBACK:
			_fresh(preset)
			var s := _cast(card_name, 1)
			var spell: CardInstance = s["spell"]
			assert_ok(g.pass_priority(0))
			var counter := give_hand(1, "Counterspell")
			add_mana(1, Mtg.ManaColor.U, 2)
			assert_ok(g.cast_spell(1, counter, [TargetRef.card(spell)]))
			resolve_stack()
			assert_eq(spell.zone, Mtg.Zone.GRAVEYARD, "%s/%s: countered, it never resolved" % [preset, card_name])


func test_a_fizzled_buyback_spell_goes_to_the_graveyard() -> void:
	for preset in ["modern", "fifth"]:
		for card_name in BUYBACK:
			if NO_FIZZLE.has(card_name): continue
			_fresh(preset)
			var s := _cast(card_name, 1)
			var victim: CardInstance = s["victim"]
			match victim.zone:
				Mtg.Zone.GRAVEYARD: g.exile_from_graveyard(victim)
				Mtg.Zone.STACK: g.counter_spell(victim)
				_: g.exile_permanent(victim)
			resolve_stack()
			assert_eq((s["spell"] as CardInstance).zone, Mtg.Zone.GRAVEYARD,
				"%s/%s: no legal target, it doesn't resolve" % [preset, card_name])


func test_a_copy_is_never_returned_and_the_original_follows_its_own_resolution() -> void:
	for card_name in BUYBACK:
		_fresh()
		var s := _cast(card_name, 1)
		var spell: CardInstance = s["spell"]
		var fork := give_hand(0, "Fork")
		add_mana(0, Mtg.ManaColor.R, 2)
		assert_ok(g.cast_spell(0, fork, [TargetRef.card(spell)]))
		resolve_stack()
		assert_eq(_copies_of(card_name), 1, "%s: the copy ceased to exist (CR 707.10a)" % card_name)
		var expected := Mtg.Zone.GRAVEYARD if COPY_TAKES_THE_TARGET.has(card_name) else Mtg.Zone.HAND
		assert_eq(spell.zone, expected, "%s: the original after its copy" % card_name)
		assert_eq(fork.zone, Mtg.Zone.GRAVEYARD)


func test_bought_back_it_is_cast_again_and_again() -> void:
	var touch := give_hand(0, "Searing Touch")
	for i in 3:
		add_mana(0, Mtg.ManaColor.R)
		add_mana(0, Mtg.ManaColor.C, 4)
		assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
		resolve_stack()
		assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 17)


func test_a_refused_buyback_pays_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var capsize := give_hand(0, "Capsize")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, capsize, [TargetRef.card(bears)], 0, 1), "not enough mana")
	assert_eq(g.players[0].mana_pool.total(), 5, "nothing paid (CR 601.2h)")
	assert_eq(capsize.zone, Mtg.Zone.HAND)
	assert_ok(g.cast_spell(0, capsize, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(capsize.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- Memory Crystal --

func test_memory_crystal_takes_two_off_every_generic_buyback() -> void:
	put_battlefield(0, "Memory Crystal")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Capsize"), 0, 1).mana_value(), 4, "{1}{U}{U} + {3} - {2}")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Capsize"), 0, 0).mana_value(), 3, "no buyback, no discount")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Corpse Dance"), 0, 1).mana_value(), 3, "{2}{B} + {2} - {2}")
	var games := g.spell_cost_for(0, CardRegistry.get_card("Mind Games"), 0, 1)
	assert_eq(games.mana_value(), 2, "{U} + {2}{U} - {2}: never a pip")
	assert_eq(int(games.colored.get(Mtg.ManaColor.U, 0)), 2)
	var peel := g.spell_cost_for(0, CardRegistry.get_card("Mind Peel"), 0, 1)
	assert_eq(peel.mana_value(), 3, "{B} + {2}{B}{B} - {2}")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Constant Mists"), 0, 1).mana_value(), 2,
		"a land buyback is no mana to discount")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Slaughter"), 0, 1).mana_value(), 4, "nor is a life one")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Allay"), 0, 1).mana_value(), 3,
		"the discount never reaches the spell's own cost")

func test_memory_crystal_casts_a_cheaper_buyback_that_returns() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Memory Crystal")
	var touch := give_hand(0, "Searing Touch")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	assert_eq(g.players[0].mana_pool.total(), 0, "{R} + {4} - {2}")
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 19)

func test_memory_crystals_apply_to_all_players_and_stop_at_zero() -> void:
	put_battlefield(1, "Memory Crystal")
	var whim := CardRegistry.get_card("Whim of Volrath")
	assert_eq(g.spell_cost_for(0, whim, 0, 1).mana_value(), 1, "their Crystal: {U} + {2} - {2}")
	put_battlefield(0, "Memory Crystal")
	assert_eq(g.spell_cost_for(0, whim, 0, 1).mana_value(), 1, "a second Crystal finds nothing more")
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Whispers of the Muse"), 0, 1).mana_value(), 2,
		"{U} + {5} - {2} - {2}")

func test_a_tapped_memory_crystal_stops_under_the_1997_rules_only() -> void:
	var crystal := put_battlefield(0, "Memory Crystal")
	var capsize := CardRegistry.get_card("Capsize")
	g.tap_permanent(crystal)
	g.rules.set_preset("modern_mana_burn")
	g.recalculate()
	assert_eq(g.spell_cost_for(0, capsize, 0, 1).mana_value(), 4, "modern: a tapped artifact still works")
	g.rules.set_preset("fifth")
	g.recalculate()
	assert_eq(g.spell_cost_for(0, capsize, 0, 1).mana_value(), 6, "fifth: a tapped artifact's static stops")
	g.untap_permanent(crystal)
	g.recalculate()
	assert_eq(g.spell_cost_for(0, capsize, 0, 1).mana_value(), 4, "fifth: untapped, it works")
