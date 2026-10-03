extends GameTest
## Pack 8 (the Mirage block), batch B7: the global-rules half of the Visions
## module (cards/sets/vis/_misc.gd) — Eye of Singularity, Peace Talks,
## Blanket of Night, Necromancy, Pillar Tombs of Aku, Elkin Lair, City of
## Solitude, Breathstealer's Crypt and Righteous War.

const CLAIMED := ["Eye of Singularity", "Peace Talks", "Blanket of Night", "Necromancy",
	"Pillar Tombs of Aku", "Elkin Lair", "City of Solitude", "Breathstealer's Crypt", "Righteous War"]


class Scripted extends DecisionAgent:
	var options: Array = []   # int index or String label fragment
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance or card name
	var offered: Array = []

	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		offered.append(", ".join(labels))
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func cast_only(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	return card


func cast(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := cast_only(name, targets, x, pid)
	resolve_stack()
	return card


func bury(pid: int, name: String) -> CardInstance:
	var inst := put_battlefield(pid, name)
	g.destroy(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst


func on_top(pid: int, name: String) -> CardInstance:
	var inst := give_hand(pid, name)
	g.put_from_hand_on_top_of_library(inst)
	return inst


func to_step_of(pid: int, step: int) -> void:
	var guard := 0
	if g.active_player == pid and g.current_step() == step:
		_advance_once()
	while not (g.active_player == pid and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------- Eye of Singularity --

func test_eye_of_singularity_destroys_every_duplicate_but_basic_lands() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var f1 := put_battlefield(0, "Forest")
	var f2 := put_battlefield(1, "Forest")
	b.regeneration_shields = 1
	cast("Eye of Singularity")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "a name nothing shares")
	assert_eq(f1.zone, Mtg.Zone.BATTLEFIELD, "basic lands are spared")
	assert_eq(f2.zone, Mtg.Zone.BATTLEFIELD)


func test_eye_of_singularity_a_newcomer_destroys_the_others_with_its_name() -> void:
	cast("Eye of Singularity")
	var old := put_battlefield(1, "Grizzly Bears")
	resolve_stack()
	assert_eq(old.zone, Mtg.Zone.BATTLEFIELD, "alone with its name")
	var fresh := cast("Grizzly Bears")
	assert_eq(fresh.zone, Mtg.Zone.BATTLEFIELD, "the newcomer stays")
	assert_eq(old.zone, Mtg.Zone.GRAVEYARD, "all OTHER permanents with that name")


func test_eye_of_singularity_ignores_a_basic_land_entering() -> void:
	cast("Eye of Singularity")
	var f1 := put_battlefield(0, "Forest")
	var f2 := give_hand(0, "Forest")
	assert_ok(g.play_land(0, f2))
	resolve_stack()
	assert_eq(f1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(f2.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------- Peace Talks --

var _trigger_hit: Array = []

func _hit(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var t: Array = game.current_targets()
	if not t.is_empty():
		_trigger_hit.append(t[0])


func _self_enter(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


func test_peace_talks_no_attacks_and_no_spell_or_ability_targets_this_turn_and_next() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	cast("Peace Talks")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.card(bear)]))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [giant.id]))
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the turn after next: targets again")


func test_peace_talks_a_triggered_ability_may_still_target() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Peace Talks")
	_trigger_hit.clear()
	var watcher := CardData.new("Test Watcher", "{1}", Mtg.CardType.CREATURE).pt(1, 1) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _hit,
			"When this enters, target creature ...", _self_enter).targeting(TargetSpec.creature()))
	var w := give_synthetic(0, watcher)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, w, []))
	resolve_stack()
	assert_eq(_trigger_hit.size(), 1, "a TRIGGER's target is not refused")


# ---------------------------------------------------------- Blanket of Night --

func test_blanket_of_night_adds_the_swamp_type_and_keeps_the_rest() -> void:
	var forest := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	cast("Blanket of Night")
	assert_true(forest.has_subtype("swamp"))
	assert_true(forest.has_subtype("forest"), "in addition to its other land types")
	assert_true(theirs.has_subtype("swamp"), "each land, both sides")
	var colors: Array = []
	for i in forest.cur_mana_abilities.size():
		colors.append(int(forest.cur_mana_abilities[i].produces[0][0]))
	assert_true(colors.has(Mtg.ManaColor.G))
	assert_true(colors.has(Mtg.ManaColor.B), "the Swamp's {T}: Add {B}")
	assert_ok(g.tap_for_mana(0, forest, colors.find(Mtg.ManaColor.B)))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)


# ---------------------------------------------------------------- Necromancy --

func test_necromancy_at_sorcery_speed_raises_and_stays() -> void:
	var p0 := seat(0)
	var dead := bury(1, "Hill Giant")
	p0.picks = [dead]
	var necro := cast("Necromancy", [])
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dead.controller_id, 0, "under your control, from either graveyard")
	assert_true(necro.is_aura(), "it became an Aura")
	assert_eq(necro.attached_to, dead.id)
	advance_to_next_turn()
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD, "cast as a sorcery: no cleanup sacrifice")
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)


func test_necromancy_leaving_sacrifices_the_creature() -> void:
	var dead := bury(0, "Hill Giant")
	var necro := cast("Necromancy", [])
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	cast("Disenchant", [TargetRef.card(necro)])
	assert_eq(necro.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD, "its creature's controller sacrifices it")
	assert_false(necro.is_aura(), "a card in a graveyard is its printed self")


func test_necromancy_at_instant_speed_is_sacrificed_at_the_next_cleanup() -> void:
	var dead := bury(0, "Hill Giant")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	var necro := cast_only("Necromancy", [], 0, 0)
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD, "cast like an instant on the opponent's turn")
	assert_eq(dead.controller_id, 0)
	advance_to_next_turn()
	assert_eq(necro.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the beginning of the next cleanup step")
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD, "and the creature with it")


## The target leaves its graveyard with the trigger on the stack: the
## trigger fizzles and the Necromancy stays a plain enchantment.
func test_necromancy_target_gone_before_resolution() -> void:
	var dead := bury(1, "Hill Giant")
	var necro := cast_only("Necromancy", [])
	resolve_stack_once()
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.stack.is_empty(), "the enters trigger waits")
	g.exile_from_graveyard(dead)
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.EXILE)
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(necro.is_aura())


func resolve_stack_once() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))


func test_necromancy_with_no_creature_card_stays_a_plain_enchantment() -> void:
	var necro := cast("Necromancy", [])
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(necro.is_aura())


# ------------------------------------------------------- Pillar Tombs of Aku --

func test_pillar_tombs_a_sacrifice_keeps_the_tombs() -> void:
	var p1 := seat(1)
	var tombs := put_battlefield(0, "Pillar Tombs of Aku")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	p1.answers = [true]
	p1.picks = [giant]
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the player's choice of creature")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)
	assert_eq(tombs.zone, Mtg.Zone.BATTLEFIELD)


func test_pillar_tombs_declined_costs_five_life_and_the_tombs() -> void:
	var p1 := seat(1)
	var tombs := put_battlefield(0, "Pillar Tombs of Aku")
	var bear := put_battlefield(1, "Grizzly Bears")
	p1.answers = [false]
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 15, "that player loses 5")
	assert_eq(tombs.zone, Mtg.Zone.GRAVEYARD, "and YOU (the Tombs' controller) sacrifice it")


func test_pillar_tombs_no_creature_at_your_own_upkeep() -> void:
	var tombs := put_battlefield(1, "Pillar Tombs of Aku")
	put_battlefield(0, "Grizzly Bears")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[1].life, 15, "no creature to sacrifice: 5 life")
	assert_eq(tombs.zone, Mtg.Zone.GRAVEYARD, "and the controller sacrifices its own Tombs")


# ---------------------------------------------------------------- Elkin Lair --

func test_elkin_lair_exiles_a_random_card_playable_this_turn() -> void:
	put_battlefield(0, "Elkin Lair")
	var bolt := give_hand(1, "Lightning Bolt")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "the only card in hand")
	assert_true(g.can_play_from_exile(1, bolt))
	assert_false(g.can_play_from_exile(0, bolt), "only that player")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_elkin_lair_an_unplayed_card_goes_to_the_graveyard_at_the_end_step() -> void:
	put_battlefield(0, "Elkin Lair")
	var a := give_hand(1, "Lightning Bolt")
	var b := give_hand(1, "Hill Giant")
	var c := give_hand(1, "Grizzly Bears")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	var exiled: Array = [a, b, c].filter(func(i: CardInstance) -> bool: return i.zone == Mtg.Zone.EXILE)
	assert_eq(exiled.size(), 1, "exactly one card, at random")
	assert_eq(g.players[1].hand.size(), 2)
	to_step_of(1, Mtg.Step.END)
	resolve_stack()
	assert_eq((exiled[0] as CardInstance).zone, Mtg.Zone.GRAVEYARD)


func test_elkin_lair_a_land_may_be_played_from_exile() -> void:
	put_battlefield(0, "Elkin Lair")
	var island := give_hand(1, "Island")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(island.zone, Mtg.Zone.EXILE)
	assert_ok(g.play_land(1, island))
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)


func test_elkin_lair_with_an_empty_hand_does_nothing() -> void:
	put_battlefield(0, "Elkin Lair")
	assert_true(g.players[1].hand.is_empty())
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_true(g.players[1].exile.is_empty())


# ---------------------------------------------------------- City of Solitude --

func test_city_of_solitude_only_on_your_own_turn() -> void:
	put_battlefield(0, "City of Solitude")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var mountain := put_battlefield(1, "Mountain")
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]), "City of Solitude")
	assert_refused(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]), "City of Solitude")
	assert_refused(g.tap_for_mana(1, mountain))
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "on their own turn")


func test_city_of_solitude_binds_its_controller_too() -> void:
	put_battlefield(0, "City of Solitude")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]))


## Phased out, the City "doesn't exist" (CR 702.26b): no ban at all.
func test_city_of_solitude_phased_out_bans_nothing() -> void:
	var city := put_battlefield(0, "City of Solitude")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	assert_true(g.phase_out(city))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 16)


# ----------------------------------------------------- Breathstealer's Crypt --

func test_breathstealers_crypt_a_noncreature_is_kept() -> void:
	put_battlefield(0, "Breathstealer's Crypt")
	var bolt := on_top(0, "Lightning Bolt")
	g.draw_cards(0, 1)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 20)


func test_breathstealers_crypt_a_creature_costs_three_life_or_the_card() -> void:
	var p0 := seat(0)
	put_battlefield(1, "Breathstealer's Crypt")
	var giant := on_top(0, "Hill Giant")
	p0.answers = [true]
	g.draw_cards(0, 1)
	assert_eq(giant.zone, Mtg.Zone.HAND, "paid")
	assert_eq(g.players[0].life, 17)
	var bear := on_top(0, "Grizzly Bears")
	p0.answers = [false]
	g.draw_cards(0, 1)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "not paid: discarded")
	assert_eq(g.players[0].life, 17)


func test_breathstealers_crypt_cannot_pay_life_it_does_not_have() -> void:
	var p0 := seat(0)
	put_battlefield(1, "Breathstealer's Crypt")
	g.adjust_life(0, -18)
	var giant := on_top(0, "Hill Giant")
	p0.answers = [true]
	g.draw_cards(0, 1)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "2 life cannot pay 3 (CR 119.4)")
	assert_eq(g.players[0].life, 2)


func test_breathstealers_crypt_draws_exactly_one_card_per_draw() -> void:
	put_battlefield(0, "Breathstealer's Crypt")
	var hand := g.players[0].hand.size()
	var library := g.players[0].library.size()
	g.draw_cards(0, 2)
	assert_eq(g.players[0].hand.size(), hand + 2, "its own draw is not replaced again (CR 614.5)")
	assert_eq(g.players[0].library.size(), library - 2)


## CR 616.1 between two draw replacements: the drawing player orders them.
## Breathstealer's first: its own inner draw is a new event the Forbidden
## Crypt still replaces — the graveyard card comes back, nothing is drawn
## or revealed, no life is asked for.
func test_breathstealers_crypt_and_forbidden_crypt_the_player_orders_them() -> void:
	var p0 := seat(0)
	var dead := bury(0, "Hill Giant")
	put_battlefield(0, "Breathstealer's Crypt")
	put_battlefield(0, "Forbidden Crypt")
	var top := on_top(0, "Grizzly Bears")
	p0.options = ["Breathstealer"]
	var library := g.players[0].library.size()
	g.draw_cards(0, 1)
	assert_true(p0.offered.size() >= 1 and p0.offered[0].contains("Forbidden Crypt") \
		and p0.offered[0].contains("Breathstealer's Crypt"), "CR 616.1: %s" % str(p0.offered))
	assert_eq(dead.zone, Mtg.Zone.HAND, "the Forbidden Crypt replaced the inner draw")
	assert_eq(top.zone, Mtg.Zone.LIBRARY, "nothing drawn")
	assert_eq(g.players[0].library.size(), library)
	assert_eq(g.players[0].life, 20)


func test_forbidden_crypt_first_with_an_empty_graveyard_loses() -> void:
	var p0 := seat(0)
	put_battlefield(0, "Breathstealer's Crypt")
	put_battlefield(0, "Forbidden Crypt")
	p0.options = ["Forbidden"]
	g.draw_cards(0, 1)
	assert_true(g.players[0].has_lost, "an empty graveyard: the Forbidden Crypt's player loses")


# ------------------------------------------------------------ Righteous War --

func test_righteous_war_white_pro_black_and_black_pro_white() -> void:
	put_battlefield(0, "Righteous War")
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	var their := put_battlefield(1, "Pearled Unicorn")
	assert_true((unicorn.cur_protection & Mtg.ManaColor.B) != 0)
	assert_true((skeletons.cur_protection & Mtg.ManaColor.W) != 0)
	assert_eq(their.cur_protection & Mtg.ManaColor.B, 0, "only creatures you control")
	assert_ok(g.pass_priority(0))
	var terror := give_hand(1, "Terror")
	fund(1, terror)
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(unicorn)]))
	var swords := give_hand(1, "Swords to Plowshares")
	fund(1, swords)
	assert_refused(g.cast_spell(1, swords, [TargetRef.card(skeletons)]))
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(their)]))
