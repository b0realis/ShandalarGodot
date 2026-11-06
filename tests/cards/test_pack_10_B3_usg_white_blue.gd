extends GameTest
## Pack 10 (the Urza block), batch B3: the white and blue Urza's Saga
## creatures of cards/sets/usg/_creatures.gd — Angelic Page, Elite Archers,
## Faith Healer, Intrepid Hero, Sanctum Custodian, Sanctum Guardian, Silent
## Attendant, Songstitcher, Barrin, Disruptive Student, Fog Bank, Wizard
## Mentor and Zephid. Each test drives the card through the public API and
## pins the clause that makes it that card, with its refused case.

const CLAIMED := ["Angelic Page", "Elite Archers", "Faith Healer", "Intrepid Hero",
	"Sanctum Custodian", "Sanctum Guardian", "Silent Attendant", "Songstitcher",
	"Barrin, Master Wizard", "Disruptive Student", "Fog Bank", "Wizard Mentor", "Zephid"]


## FIFO answers; an empty queue falls back to the caller's hint.
class Scripted extends DecisionAgent:
	var picks: Array = []     # CardInstance, card name, or null (decline)
	var answers: Array = []   # bool
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## [param pid] casts [param card_name] at [param targets] and keeps the
## stack (priority stays with the caster).
func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := cast_only(card_name, targets, pid)
	resolve_stack()
	return card

## P0 Bolts [param target] and passes, so P1 holds priority over it.
func bolt_pending(target: TargetRef) -> CardInstance:
	var bolt := cast_only("Lightning Bolt", [target])
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	return bolt

## P0 attacks with [param attackers]; P1 is to declare blockers.
func _attack(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)

## P1 declares [param blocks]; then P0 passes, so P1 holds priority in the
## declare blockers step.
func _blocks_then_p1(blocks: Dictionary) -> void:
	assert_ok(g.declare_blockers(1, blocks))
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_eq(c.set_code, "usg", card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Angelic Page -----------------------------------------------------------

func test_angelic_page_lifts_only_a_creature_in_combat() -> void:
	var page := put_battlefield(0, "Angelic Page")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(page.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, page, 0, [TargetRef.card(bear)]))
	_attack([bear])
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.priority_player, 0)
	assert_ok(g.activate_ability(0, page, 0, [TargetRef.card(bear)]))
	assert_true(page.tapped)
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	advance_to_next_turn()
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])


# --- Elite Archers ----------------------------------------------------------

func test_elite_archers_shoot_an_attacker_but_not_a_bystander_or_a_player() -> void:
	var archers := put_battlefield(1, "Elite Archers")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([giant])
	_blocks_then_p1({})
	assert_refused(g.activate_ability(1, archers, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(1, archers, 0, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(1, archers, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_elite_archers_shoot_a_blocker_too() -> void:
	var archers := put_battlefield(0, "Elite Archers")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Hill Giant")
	_attack([bear])
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	assert_eq(g.priority_player, 0)
	assert_ok(g.activate_ability(0, archers, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


# --- Faith Healer -----------------------------------------------------------

func test_faith_healer_turns_an_enchantment_into_its_mana_value_in_life() -> void:
	var healer := put_battlefield(0, "Faith Healer")
	put_battlefield(1, "Crusade")
	assert_refused(g.activate_ability(0, healer, 0), "enchantment")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var lure := cast("Lure", [TargetRef.card(theirs)])
	assert_eq(lure.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.activate_ability(0, healer, 0))
	assert_eq(lure.zone, Mtg.Zone.GRAVEYARD, "our Aura on their creature is ours to sacrifice")
	resolve_stack()
	assert_eq(g.players[0].life, 23, "Lure's mana value is 3")

func test_faith_healer_reads_each_activation_s_own_sacrifice() -> void:
	var p0 := seat(0)
	var healer := put_battlefield(0, "Faith Healer")
	var crusade := put_battlefield(0, "Crusade")
	var bad_moon := put_battlefield(0, "Bad Moon")
	var lure_host := put_battlefield(0, "Grizzly Bears")
	var lure := cast("Lure", [TargetRef.card(lure_host)])
	p0.picks = [lure, crusade]
	assert_ok(g.activate_ability(0, healer, 0))
	assert_ok(g.activate_ability(0, healer, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 25, "3 + 2, one per activation")
	assert_eq(bad_moon.zone, Mtg.Zone.BATTLEFIELD)


# --- Intrepid Hero ----------------------------------------------------------

func test_intrepid_hero_destroys_only_power_four_or_greater() -> void:
	var hero := put_battlefield(0, "Intrepid Hero")
	var wurm := put_battlefield(1, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, hero, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, hero, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	var sick := put_battlefield(0, "Intrepid Hero", true)
	cast("Giant Growth", [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 5, "power read live")
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(bear)]))
	var other := put_battlefield(0, "Intrepid Hero")
	assert_ok(g.activate_ability(0, other, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --- Sanctum Custodian ------------------------------------------------------

func test_sanctum_custodian_prevents_two_to_any_target() -> void:
	var custodian := put_battlefield(1, "Sanctum Custodian")
	bolt_pending(TargetRef.player(1))
	assert_ok(g.activate_ability(1, custodian, 0, [TargetRef.player(1)]))
	assert_true(custodian.tapped)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "3 - 2")
	assert_true(CardRegistry.get_card("Sanctum Custodian").activated_abilities[0].effects[0].is_damage_prevention)


# --- Sanctum Guardian -------------------------------------------------------

func test_sanctum_guardian_sacrifices_itself_to_shield_from_a_chosen_source() -> void:
	var p1 := seat(1)
	var guardian := put_battlefield(1, "Sanctum Guardian")
	var giant := put_battlefield(1, "Hill Giant")
	bolt_pending(TargetRef.card(giant))
	p1.picks = ["Lightning Bolt"]
	assert_ok(g.activate_ability(1, guardian, 0, [TargetRef.card(giant)]))
	assert_eq(guardian.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is the cost")
	resolve_stack()
	assert_eq(giant.damage, 0)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_sanctum_guardian_shields_a_player_once() -> void:
	var p1 := seat(1)
	var guardian := put_battlefield(1, "Sanctum Guardian")
	bolt_pending(TargetRef.player(1))
	p1.picks = ["Lightning Bolt"]
	assert_ok(g.activate_ability(1, guardian, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17, "another source is not shielded")


# --- Silent Attendant -------------------------------------------------------

func test_silent_attendant_taps_for_a_life() -> void:
	var sick := put_battlefield(0, "Silent Attendant", true)
	assert_refused(g.activate_ability(0, sick, 0))
	var attendant := put_battlefield(0, "Silent Attendant")
	assert_ok(g.activate_ability(0, attendant, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_refused(g.activate_ability(0, attendant, 0))


# --- Songstitcher -----------------------------------------------------------

func test_songstitcher_silences_an_attacking_flyer_only() -> void:
	var stitcher := put_battlefield(1, "Songstitcher")
	var angel := put_battlefield(0, "Serra Angel")
	var giant := put_battlefield(0, "Hill Giant")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(1, stitcher, 0, [TargetRef.card(angel)]))
	_attack([angel, giant])
	_blocks_then_p1({})
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(1, stitcher, 0, [TargetRef.card(angel)]), "mana")
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(1, stitcher, 0, [TargetRef.card(giant)]))
	assert_ok(g.activate_ability(1, stitcher, 0, [TargetRef.card(angel)]))
	assert_false(stitcher.tapped, "no {T} in the cost")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "only the Giant's 3")


# --- Barrin, Master Wizard --------------------------------------------------

func test_barrin_sacrifices_a_permanent_to_return_a_creature() -> void:
	var p0 := seat(0)
	var barrin := put_battlefield(0, "Barrin, Master Wizard")
	var island := put_battlefield(0, "Island")
	var giant := put_battlefield(1, "Hill Giant")
	assert_true((barrin.data.supertypes & Mtg.Supertype.LEGENDARY) != 0)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, barrin, 0, [TargetRef.card(giant)]), "mana")
	add_mana(0, Mtg.ManaColor.C)
	p0.picks = [island]
	assert_ok(g.activate_ability(0, barrin, 0, [TargetRef.card(giant)]))
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(barrin.zone, Mtg.Zone.BATTLEFIELD)

func test_barrin_may_sacrifice_himself() -> void:
	var p0 := seat(0)
	var barrin := put_battlefield(0, "Barrin, Master Wizard")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	p0.picks = [barrin]
	assert_ok(g.activate_ability(0, barrin, 0, [TargetRef.card(giant)]))
	assert_eq(barrin.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)


# --- Disruptive Student -----------------------------------------------------

func test_disruptive_student_counters_unless_the_caster_pays_one() -> void:
	var student := put_battlefield(1, "Disruptive Student")
	var bears := cast_only("Grizzly Bears")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, student, 0, [TargetRef.card(bears)]))
	assert_true(student.tapped)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "nothing to pay with")

func test_disruptive_student_is_paid_off_with_one_mana() -> void:
	var student := put_battlefield(1, "Disruptive Student")
	var mountain := put_battlefield(0, "Mountain")
	var bears := cast_only("Grizzly Bears")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, student, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(mountain.tapped, "the {1} was paid")

func test_disruptive_student_payer_may_decline() -> void:
	var p0 := seat(0)
	p0.answers = [false]
	var student := put_battlefield(1, "Disruptive Student")
	put_battlefield(0, "Mountain")
	var bears := cast_only("Grizzly Bears")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, student, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


# --- Fog Bank ---------------------------------------------------------------

func test_fog_bank_neither_takes_nor_deals_combat_damage() -> void:
	var bank := put_battlefield(1, "Fog Bank")
	var giant := put_battlefield(0, "Hill Giant")
	assert_true(bank.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(bank.has_keyword(Mtg.Keyword.FLYING))
	g.continuous.add_until_eot_pump(bank.id, 3, 0)
	g.recalculate()
	_attack([giant])
	assert_ok(g.declare_blockers(1, {bank.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bank.damage, 0)
	assert_eq(giant.damage, 0, "its own 3 power is prevented too")
	assert_eq(bank.zone, Mtg.Zone.BATTLEFIELD)

func test_fog_bank_still_dies_to_a_bolt() -> void:
	var bank := put_battlefield(1, "Fog Bank")
	cast("Lightning Bolt", [TargetRef.card(bank)])
	assert_eq(bank.zone, Mtg.Zone.GRAVEYARD, "only combat damage is prevented")


# --- Wizard Mentor ----------------------------------------------------------

func test_wizard_mentor_returns_itself_and_a_creature_you_control() -> void:
	var mentor := put_battlefield(0, "Wizard Mentor")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, mentor, 0, [TargetRef.card(theirs)]))
	assert_ok(g.activate_ability(0, mentor, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(mentor.zone, Mtg.Zone.HAND)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)

func test_wizard_mentor_may_target_itself() -> void:
	var mentor := put_battlefield(0, "Wizard Mentor")
	assert_ok(g.activate_ability(0, mentor, 0, [TargetRef.card(mentor)]))
	resolve_stack()
	assert_eq(mentor.zone, Mtg.Zone.HAND)

## CR 608.2b: the only target gone, the ability does nothing — the Mentor
## stays.
func test_wizard_mentor_stays_when_its_target_is_gone() -> void:
	var mentor := put_battlefield(0, "Wizard Mentor")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, mentor, 0, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var unsummon := give_hand(1, "Unsummon")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, unsummon, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(mentor.zone, Mtg.Zone.BATTLEFIELD)


# --- Zephid -----------------------------------------------------------------

func test_zephid_flies_and_has_shroud() -> void:
	var zephid := put_battlefield(0, "Zephid")
	assert_true(zephid.has_keyword(Mtg.Keyword.FLYING))
	assert_true(zephid.cur_shroud)
	assert_eq([zephid.cur_power, zephid.cur_toughness], [3, 4])
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(zephid)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(zephid)]))
