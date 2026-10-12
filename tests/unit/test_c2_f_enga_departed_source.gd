extends GameTest
## A DAMAGE SOURCE THAT HAS LEFT THE BATTLEFIELD (campaign 2026-10-12).
##
## b3-3 — CR 609.7a: "a source of your choice" may be any object referred
## to by an object on the stack, "even if that object is no longer in the
## zone it used to be in". A Mogg Fanatic sacrificed to ping you, or a
## Prodigal Sorcerer killed in response to its own ping, is still the
## source of that damage, and a Circle of Protection may name it.
## MtgGame.damage_sources offered only the battlefield, spells on the stack
## and waiting damage, so the Circle had nothing to name.
##
## b3-5 — CR 113.7a / 608.2h: when the ability resolves, a source that is
## no longer where its ability expects it is read as it last existed.
## A Fanatic made blue by Thoughtlace is a BLUE source after it is
## sacrificed, so its ping is legal against a pro-red Soltari Priest; a
## Clone that was a Mogg Fanatic is a RED source after it dies, so its ping
## reaches a pro-blue Karoo Meerkat. Both used to fizzle on the printed
## colour the card went back to.
##
## Both rules presets: an AI or headless seat never opens the 1997
## prevention step, so the Circle takes its modern form under either.

const PACKS := ["pack-8", "pack-9"]
const PRESETS := ["modern_mana_burn", "fifth"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _fresh(preset: String) -> void:
	super.before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


# ------------------------------------------------------------- b3-3 --

func test_cop_red_names_a_sacrificed_mogg_fanatic() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var fanatic := put_battlefield(0, "Mogg Fanatic")
		var cop := put_battlefield(1, "Circle of Protection: Red")
		assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.player(1)]))
		assert_eq(fanatic.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
		assert_true(g.damage_sources().has(fanatic),
			"%s: the ability on the stack refers to the Fanatic" % preset)
		assert_ok(g.pass_priority(0))
		add_mana(1, Mtg.ManaColor.W)
		assert_ok(g.activate_ability(1, cop, 0, []))
		resolve_stack()
		assert_eq(g.players[1].life, 20, "%s: the Circle named the Fanatic" % preset)


func test_cop_blue_names_a_prodigal_sorcerer_killed_in_response() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
		var cop := put_battlefield(1, "Circle of Protection: Blue")
		assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
		assert_ok(g.pass_priority(0))
		var bolt := give_hand(1, "Lightning Bolt")
		add_mana(1, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(1, bolt, [TargetRef.card(sorcerer)]))
		var guard := 0
		while g.stack.size() > 1 and guard < 10:
			assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		assert_eq(sorcerer.zone, Mtg.Zone.GRAVEYARD, "%s: the Bolt killed it" % preset)
		assert_eq(g.stack.size(), 1, "%s: its ping is still waiting" % preset)
		if g.priority_player == 0:
			assert_ok(g.pass_priority(0))
		add_mana(1, Mtg.ManaColor.W)
		assert_ok(g.activate_ability(1, cop, 0, []))
		resolve_stack()
		assert_eq(g.players[1].life, 20, "%s: the Circle named the dead Sorcerer" % preset)


# The list does not become the graveyard: once nothing on the stack refers
# to the departed card, it is not a source anyone may name.
func test_a_departed_card_is_offered_only_while_its_ability_waits() -> void:
	_fresh("modern_mana_burn")
	var fanatic := put_battlefield(0, "Mogg Fanatic")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.card(bears)]))
	assert_true(g.damage_sources().has(fanatic))
	resolve_stack()
	assert_eq(bears.damage, 1)
	assert_false(g.damage_sources().has(fanatic), "nothing refers to it any more")


# ------------------------------------------------------------- b3-5 --

func test_a_laced_fanatic_is_blue_as_it_last_existed() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var fanatic := put_battlefield(0, "Mogg Fanatic")
		var priest := put_battlefield(1, "Soltari Priest")   # protection from red
		_lace(fanatic)
		assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.card(priest)]))
		assert_eq(g.damage_source_colors(fanatic), Mtg.ManaColor.U,
			"%s: the departed source is read as it last existed" % preset)
		resolve_stack()
		# A 2/1: the point that reaches it is lethal.
		assert_eq(priest.zone, Mtg.Zone.GRAVEYARD,
			"%s: a blue source's ping reaches the pro-red Priest" % preset)


func test_a_clone_that_was_a_fanatic_is_red_as_it_last_existed() -> void:
	for preset in PRESETS:
		_fresh(preset)
		put_battlefield(0, "Mogg Fanatic")
		var clone := put_battlefield(0, "Clone")
		assert_eq(clone.data.card_name, "Mogg Fanatic")
		var meerkat := put_battlefield(1, "Karoo Meerkat")   # protection from blue
		assert_ok(g.activate_ability(0, clone, 0, [TargetRef.card(meerkat)]))
		resolve_stack()
		# A 2/1: the point that reaches it is lethal.
		assert_eq(meerkat.zone, Mtg.Zone.GRAVEYARD,
			"%s: the red copy's ping reaches the pro-blue Meerkat" % preset)


# The two halves together: the laced Fanatic's ping comes from a BLUE
# source, so a Circle of Protection: Red has nothing to name and a Circle
# of Protection: Blue does.
func test_the_circle_reads_the_departed_source_s_last_colour() -> void:
	_fresh("modern_mana_burn")
	var fanatic := put_battlefield(0, "Mogg Fanatic")
	var red := put_battlefield(1, "Circle of Protection: Red")
	_lace(fanatic)
	assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(1, red, 0, []))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "a red Circle cannot name a blue source")

	_fresh("modern_mana_burn")
	fanatic = put_battlefield(0, "Mogg Fanatic")
	var blue := put_battlefield(1, "Circle of Protection: Blue")
	_lace(fanatic)
	assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(1, blue, 0, []))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "a blue Circle names it")


# Last-known information belongs to the ability that was in flight. Once
# it has resolved, the card in the graveyard is just a red card again —
# it is not "the blue Fanatic" forever.
func test_last_known_colour_ends_with_the_ability() -> void:
	_fresh("modern_mana_burn")
	var fanatic := put_battlefield(0, "Mogg Fanatic")
	_lace(fanatic)
	assert_ok(g.activate_ability(0, fanatic, 0, [TargetRef.player(1)]))
	assert_eq(g.damage_source_colors(fanatic), Mtg.ManaColor.U)
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(fanatic.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.damage_source_colors(fanatic), Mtg.ManaColor.R,
		"no ability refers to it: its own colour")


# A source still on the battlefield is read live, laced or not.
func test_a_permanent_on_the_battlefield_is_read_live() -> void:
	_fresh("modern_mana_burn")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var priest := put_battlefield(1, "Soltari Priest")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(priest)]))
	assert_eq(g.damage_source_colors(sorcerer), Mtg.ManaColor.U)
	resolve_stack()
	assert_eq(priest.zone, Mtg.Zone.GRAVEYARD, "a blue ping kills the pro-red 2/1")


## P0 laces [param inst] blue with a real Thoughtlace.
func _lace(inst: CardInstance) -> void:
	var lace := give_hand(0, "Thoughtlace")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(inst)]))
	resolve_stack()
	assert_eq(inst.cur_colors, Mtg.ManaColor.U, "laced blue")


# "That source's controller" for a stolen Fanatic the thief sacrificed is
# the thief, though the card went home to its owner's graveyard — the seat
# its ability on the stack belongs to (MtgGame.source_controller).
func test_a_stolen_departed_source_keeps_its_last_controller() -> void:
	_fresh("modern_mana_burn")
	var fanatic := _make_instance(0, "Mogg Fanatic")   # P0 owns it
	g._put_on_battlefield(fanatic, 1)                  # P1 controls it
	fanatic.summoning_sick = false
	assert_eq(fanatic.controller_id, 1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, fanatic, 0, [TargetRef.player(0)]))
	assert_eq(fanatic.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fanatic.controller_id, 0, "home to its owner")
	assert_eq(g.source_controller(fanatic), 1, "the thief, as it last existed")
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_eq(g.source_controller(fanatic), 0, "nothing refers to it any more")
