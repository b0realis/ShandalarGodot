extends GameTest
## The Mirage bug pass (Pack 8, 0.50.11), engine batch B1 — four findings:
##
## (a) ACTIVATION BANS under the 1997 rule "a tapped artifact's continuous
##     effects cease" (RulesOptions.tapped_artifacts_stop, manual p.124):
##     a tapped Null Rod / Cursed Totem bans nothing, exactly as a tapped
##     play-ban artifact already did (`MtgGame.activation_ban_reason` now
##     skips a suspended source, as `play_banned` does) — tap_for_mana,
##     activate_ability and the mana planner alike. Modern: tapping changes
##     nothing.
## (b) COST MODIFIERS are static abilities: one whose source has lost its
##     abilities (Titania's Song, CR 613.1f) or — 1997 rule — is a tapped
##     noncreature artifact (Helm of Awakening, Mana Matrix, Planar Gate,
##     Stone Calendar) changes no cost. `spell_surcharge`, `spell_cost_for`
##     and `ability_surcharge` skip it, so the castability helpers
##     (`can_afford`, `could_afford`) give the same answer as the cast.
## (c) Hall of Gemstone's "produce mana of the chosen color instead of any
##     other COLOR": colourless is not a colour (CR 105.1, 105.2c), so a
##     Karoo's {C}{U} becomes {C}{R}, not {R}{R}
##     (`ManaAbility.forcing_color(..., colored_only)`); Deep Water's "any
##     other TYPE" still recolours everything.
## (d) `ActivatedAbility.per_turn(n)` writes the printed "Activate only once
##     each turn." / "no more than twice …" into an ability text that lacks
##     it (Spitting Drake, Kyscu Drake, Wild Aesthir), never twice; the
##     Alliances / Ice Age / Homelands rules modules no longer prefix their
##     own "At most N activation(s)" on top, and every capped ability in the
##     whole pool, every pack on, states its cap exactly once.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	# Every pack off, whatever a test below switched on (as
	# test_every_pack_invariants_2026_09_25.gd leaves the suite).
	Settings.set_enabled_card_packs([] as Array[String])
	CardPacks.rescan()


class Seat extends DecisionAgent:
	var colors: Array = []
	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint


func _to_step_of(pid: int, step: int) -> void:
	var guard := 0
	if g.active_player == pid and g.current_step() == step:
		_advance_once()
	while not (g.active_player == pid and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1


## Layer 6 for the tests below: every permanent whose name is in
## [constant SILENCED] loses all abilities (Titania's Song's shape).
const SILENCED := ["Gloom", "Test Black Tax"]

static func _silence_named(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if SILENCED.has(inst.data.card_name):
			inst.cur_abilities_silenced = true


func _put_silencer(pid: int) -> CardInstance:
	return put_synthetic(pid, CardData.new("Test Silence", "{1}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence_named,
			"Gloom and Test Black Tax lose all abilities.").silencing_abilities()))


# ------------------------------------------------------------------- (a) --

func test_a_tapped_null_rod_bans_nothing_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	assert_true(g.rules.tapped_artifacts_stop)
	var rod := put_battlefield(1, "Null Rod")
	var mox := put_battlefield(0, "Mox Pearl")
	assert_refused(g.tap_for_mana(0, mox), "Null Rod")   # untapped: the ban holds
	g.tap_permanent(rod)
	g.recalculate()
	assert_true(rod.cur_statics_suspended, "precondition: the 1997 rule suspended the Rod")
	assert_eq(g.activation_ban_reason(0, mox, mox.cur_mana_abilities[0], true), "",
		"a tapped Null Rod's continuous effect has ceased")
	assert_true(g.can_afford_cost(0, ManaCost.parse("{W}")),
		"the mana planner counts the Mox again")
	assert_ok(g.tap_for_mana(0, mox))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)


func test_a_tapped_cursed_totem_bans_nothing_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	var totem := put_battlefield(1, "Cursed Totem")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(0, "Llanowar Elves")
	assert_refused(g.tap_for_mana(0, elves), "Cursed Totem")
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]), "Cursed Totem")
	g.tap_permanent(totem)
	assert_true(totem.cur_statics_suspended)
	assert_ok(g.tap_for_mana(0, elves))
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_a_tapped_null_rod_still_bans_under_modern_rules() -> void:
	assert_false(g.rules.tapped_artifacts_stop)
	var rod := put_battlefield(1, "Null Rod")
	var mox := put_battlefield(0, "Mox Pearl")
	g.tap_permanent(rod)
	g.recalculate()
	assert_false(rod.cur_statics_suspended)
	assert_refused(g.tap_for_mana(0, mox), "Null Rod")
	assert_false(g.can_afford_cost(0, ManaCost.parse("{W}")))


# ------------------------------------------------------------------- (b) --

func test_b_a_tapped_helm_of_awakening_discounts_nothing_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	var helm := put_battlefield(1, "Helm of Awakening")
	var bear := give_hand(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	assert_eq(g.spell_surcharge(0, bear.data), -1, "untapped: spells cost {1} less")
	g.tap_permanent(helm)
	g.recalculate()
	assert_true(helm.cur_statics_suspended)
	assert_eq(g.spell_surcharge(0, bear.data), 0, "tapped: its continuous effect has ceased")
	assert_false(g.could_afford(0, bear.data, {}, bear),
		"one Forest no longer pays for a {1}{G} Bears — the highlight agrees with the cast")
	add_mana(0, Mtg.ManaColor.G)
	assert_false(g.can_afford(0, bear.data, bear))
	assert_refused(g.cast_spell(0, bear))
	add_mana(0, Mtg.ManaColor.C)
	assert_true(g.can_afford(0, bear.data, bear))
	assert_ok(g.cast_spell(0, bear))
	assert_false(forest.tapped)


func test_b_a_tapped_helm_of_awakening_still_discounts_under_modern_rules() -> void:
	var helm := put_battlefield(1, "Helm of Awakening")
	var bear := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	g.tap_permanent(helm)
	g.recalculate()
	assert_eq(g.spell_surcharge(0, bear.data), -1)
	assert_true(g.could_afford(0, bear.data, {}, bear))
	add_mana(0, Mtg.ManaColor.G)
	assert_true(g.can_afford(0, bear.data, bear))
	assert_ok(g.cast_spell(0, bear))


func test_b_a_helm_that_lost_its_abilities_discounts_nothing() -> void:
	var helm := put_battlefield(1, "Helm of Awakening")
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_true(helm.cur_abilities_silenced, "precondition: the Song took the Helm's abilities")
	var bear := give_hand(0, "Grizzly Bears")
	assert_eq(g.spell_surcharge(0, bear.data), 0)
	add_mana(0, Mtg.ManaColor.G)
	assert_false(g.can_afford(0, bear.data, bear))
	assert_refused(g.cast_spell(0, bear))


func test_b_the_older_discount_artifacts_stop_when_tapped_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	var blast := CardRegistry.get_card("Lightning Bolt")
	var giant := CardRegistry.get_card("Hill Giant")
	for row in [["Mana Matrix", blast, -2], ["Planar Gate", giant, -2],
			["Stone Calendar", giant, -1]]:
		var discounter := put_battlefield(0, String(row[0]))
		var data: CardData = row[1]
		assert_eq(g.spell_surcharge(0, data), int(row[2]), "%s untapped" % row[0])
		g.tap_permanent(discounter)
		g.recalculate()
		assert_eq(g.spell_surcharge(0, data), 0, "%s tapped: nothing" % row[0])
		g.sacrifice_permanent(discounter)


func test_b_a_silenced_gloom_taxes_nothing() -> void:
	put_battlefield(1, "Gloom")
	var circle := put_battlefield(0, "Circle of Protection: Red")
	var white := CardRegistry.get_card("Savannah Lions")
	assert_eq(g.spell_surcharge(0, white), 3, "control: white spells cost {3} more")
	assert_eq(g.ability_surcharge(0, circle), 3, "control: a white enchantment's ability too")
	_put_silencer(0)
	g.recalculate()
	assert_eq(g.spell_surcharge(0, white), 0, "a Gloom without abilities taxes no spell")
	assert_eq(g.ability_surcharge(0, circle), 0, "nor an ability")


static func _black_tax(_g: MtgGame, pid: int, card: CardData, source: CardInstance) -> Dictionary:
	if pid == source.controller_id and (card.color_mask() & Mtg.ManaColor.B) != 0:
		return {Mtg.ManaColor.B: 1}
	return {}


## The coloured half of the hook (Derelor's "Black spells you cast cost
## {B} more"), on a synthetic so the test needs no optional pack.
func test_b_a_silenced_coloured_tax_adds_no_pip() -> void:
	var data := CardData.new("Test Black Tax", "{1}", Mtg.CardType.ARTIFACT)
	data.cost_modifier["spell_colored"] = _black_tax
	put_synthetic(0, data)
	var drain := CardRegistry.get_card("Dark Ritual")
	assert_eq(g.spell_cost_for(0, drain).mana_value(), 2, "control: {B} plus the tax's {B}")
	_put_silencer(1)
	g.recalculate()
	assert_eq(g.spell_cost_for(0, drain).mana_value(), 1, "silenced: the printed {B}")


# ------------------------------------------------------------------- (c) --

func test_c_hall_of_gemstone_leaves_a_karoos_colourless_half_alone() -> void:
	var seat := Seat.new()
	g.set_agent(1, seat)
	put_battlefield(0, "Hall of Gemstone")
	put_battlefield(1, "Island")   # the Karoo's bounce has an Island to take
	var atoll := put_battlefield(1, "Coral Atoll")
	resolve_stack()
	assert_eq(atoll.zone, Mtg.Zone.BATTLEFIELD, "setup: the Karoo stays")
	seat.colors = [Mtg.ManaColor.R]
	_to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	atoll.tapped = false
	var ability: ManaAbility = atoll.cur_mana_abilities[0]
	var produced := {}
	for pair in ability.produces:
		produced[int(pair[0])] = int(produced.get(int(pair[0]), 0)) + int(pair[1])
	assert_eq(produced, {Mtg.ManaColor.C: 1, Mtg.ManaColor.R: 1},
		"what the planner and the menu read: {C}{R}")
	assert_ok(g.tap_for_mana(1, atoll))
	var pool := g.players[1].mana_pool
	assert_eq(pool.amount_of(Mtg.ManaColor.R), 1, "the coloured half becomes red")
	assert_eq(pool.amount_of(Mtg.ManaColor.C), 1, "the colourless half stays colourless")
	assert_eq(pool.amount_of(Mtg.ManaColor.U), 0)


func test_c_forcing_color_recolours_every_type_unless_asked_for_colours_only() -> void:
	var karoo := ManaAbility.new(Mtg.ManaColor.C).and_also(Mtg.ManaColor.U)
	var every := karoo.forcing_color(Mtg.ManaColor.R)
	assert_eq(every.produces, [[Mtg.ManaColor.R, 1], [Mtg.ManaColor.R, 1]],
		"\"instead of any other TYPE\" (Deep Water): colourless too")
	assert_eq(every.forced_output_color, Mtg.ManaColor.R)
	var colours := karoo.forcing_color(Mtg.ManaColor.R, false, true)
	assert_eq(colours.produces, [[Mtg.ManaColor.C, 1], [Mtg.ManaColor.R, 1]],
		"\"instead of any other COLOR\" (Hall of Gemstone): colourless stays")
	assert_eq(colours.unreplaced_ability, karoo)
	# A later full replacement over the colours-only copy is a full one.
	var over := colours.forcing_color(Mtg.ManaColor.U)
	assert_eq(over.produces, [[Mtg.ManaColor.U, 1], [Mtg.ManaColor.U, 1]])
	assert_eq(over.forced_output_color, Mtg.ManaColor.U)


## Deep Water ("produces {U} instead of any other TYPE") over the same
## Karoo: both halves become blue — the existing full replacement.
func test_c_deep_water_still_recolours_a_karoos_colourless_half() -> void:
	put_battlefield(0, "Island")
	var atoll := put_battlefield(0, "Coral Atoll")
	resolve_stack()
	var water := give_hand(0, "Deep Water")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, water))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.U)
	var deep: int = -1
	for i in water.cur_activated_abilities.size():
		deep = i
	assert_ok(g.activate_ability(0, water, deep))
	resolve_stack()
	g.players[0].mana_pool.clear()
	atoll.tapped = false
	assert_ok(g.tap_for_mana(0, atoll))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 0)


# ------------------------------------------------------------------- (d) --

func test_d_once_a_turn_texts_carry_the_printed_restriction() -> void:
	CardPacks.set_enabled("pack-5", true)   # Wild Aesthir is Alliances
	CardRegistry.ensure_loaded()
	for card_name in ["Spitting Drake", "Kyscu Drake", "Wild Aesthir"]:
		var data := CardRegistry.get_card(card_name)
		assert_not_null(data, card_name)
		if data == null:
			continue
		var ability: ActivatedAbility = data.activated_abilities[0]
		assert_eq(ability.max_per_turn, 1, "%s: the rule is enforced" % card_name)
		assert_eq(ability.text.count("Activate only once each turn."), 1,
			"%s reads '%s'" % [card_name, ability.text])


func test_d_per_turn_never_writes_the_restriction_twice() -> void:
	var drake := CardRegistry.get_card("Fire Drake")
	assert_eq(drake.activated_abilities[0].text.count("once each turn"), 1,
		"Fire Drake's text already said it")
	var once := ActivatedAbility.new("{R}", false, [], "{R}: Do a thing").per_turn(1)
	assert_eq(once.text, "{R}: Do a thing. Activate only once each turn.")
	var twice := ActivatedAbility.new("{2}", false, [], "{2}: Do a thing.").per_turn(2)
	assert_eq(twice.text, "{2}: Do a thing. Activate no more than twice each turn.")
	var thrice := ActivatedAbility.new("{B}", false, [], "{B}: Do a thing.").per_turn(3)
	assert_eq(thrice.text, "{B}: Do a thing. Activate no more than three times each turn.")
	var said := ActivatedAbility.new("{B}", false, [],
		"{B}: Do a thing. Activate no more than three times each turn.").per_turn(3)
	assert_eq(said.text.count("each turn"), 1)
	assert_eq(ActivatedAbility.new("", false, [], "").per_turn(1).text, "",
		"a textless ability stays textless")


const ALL_PACKS: Array[String] = [CardPacks.ID, FallenEmpiresPack.ID,
	IceAgePack.ID, HomelandsPack.ID, AlliancesPack.ID, PortalPack.ID,
	FifthEditionPack.ID, MirageBlockPack.ID]


## The whole pool, every pack on: per_turn() is the only setter of
## max_per_turn, so every capped activated ability says its cap — once,
## in the oracle's words, and never in the old "At most N activation(s)"
## prefix the three rules modules used to add as well.
func test_d_every_capped_ability_in_the_pool_states_its_cap_once() -> void:
	Settings.set_enabled_card_packs(ALL_PACKS)
	CardPacks.rescan()
	for id in ALL_PACKS:
		assert_true(CardPacks.is_enabled(id), id + " is available to the suite")
	var wrong: Array[String] = []
	var capped := 0
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		for ability in data.activated_abilities:
			if ability.max_per_turn <= 0:
				continue
			capped += 1
			var line := ability.text.to_lower()
			var says := line.count(ActivatedAbility.per_turn_words(ability.max_per_turn) + " each turn")
			if says != 1 or line.contains("activation(s)"):
				wrong.append("%s: %s" % [card_name, ability.text])
	assert_gt(capped, 20, "the pool's capped abilities were walked")
	assert_eq(wrong, [] as Array[String], "a capped ability that does not state its cap exactly once")
