extends GameTest
## Pack 8 (the Mirage block), batch B7: the DAMAGE half of the replacement
## and global-rules suite — Benevolent Unicorn, Shadowbane, Circle of
## Despair, Reflect Damage, Soul Echo, Kaervek's Torch, Torrent of Lava
## (cards/sets/mir/_misc.gd) and Honorable Passage, Righteous Aura,
## Lichenthrope, Ogre Enforcer (cards/sets/vis/_misc.gd), over the E5
## damage replacement suite (engine/damage_replacements.gd).
##
## Pinned beside the cards' own clauses: CR 616.1 — the affected player
## ORDERS these shields against an existing Circle of Protection, and the
## order is visible (who gains life, which shield is left standing) — and
## the 1997 damage-prevention window (RulesOptions.damage_prevention_window),
## where the same instants and abilities are used AFTER the damage has been
## dealt and is waiting, against the modern profile's before-the-fact use.

const CLAIMED := ["Benevolent Unicorn", "Shadowbane", "Circle of Despair", "Reflect Damage",
	"Soul Echo", "Kaervek's Torch", "Torrent of Lava", "Honorable Passage", "Righteous Aura",
	"Lichenthrope", "Ogre Enforcer"]


## FIFO answers; an empty queue falls back to the caller's hint (the
## default seat's behaviour). [member window] opts into the 1997 window.
class Scripted extends DecisionAgent:
	var options: Array = []   # int index or String label fragment
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance or card name
	var asked: Array[String] = []
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		asked.append(", ".join(labels))
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


## A fresh game inside one test (the pack stays enabled).
func _fresh() -> void:
	super.before_each()
	advance_to_step(Mtg.Step.MAIN1)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


## Exactly the mana [param card]'s cost asks for (X paid as colourless).
func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


## Cast without resolving: the caller answers it.
func cast_only(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	return card


func cast(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := cast_only(name, targets, x, pid)
	resolve_stack()
	return card


## P0 Bolts [param target] and passes, so P1 holds priority over it.
func bolt_pending(target: TargetRef) -> CardInstance:
	var bolt := cast_only("Lightning Bolt", [target])
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	return bolt


func pestilence_pending(pest: CardInstance) -> void:
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, pest, 0))
	assert_ok(g.pass_priority(0))


## The 1997 profile, P1 asking for the window: an unblocked attacker's
## combat damage waits as a packet; returns with the window open.
func to_the_1997_window(attacker: CardInstance, defender: Scripted) -> void:
	g.rules.damage_prevention_window = true
	defender.window = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the 1997 damage prevention step is open")
	assert_eq(g.players[1].life, 20, "the damage is waiting, not dealt")


## Give [param pid] priority inside the open window (the other seat passes).
func window_priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_prevention)
	assert_eq(g.priority_player, pid)


func close_window() -> void:
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration or not g.stack.is_empty()) \
			and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 20)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------- Benevolent Unicorn --

func test_benevolent_unicorn_shaves_a_spell_but_not_an_ability() -> void:
	put_battlefield(1, "Benevolent Unicorn")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 18, "a spell's 3 becomes 2")
	cast("Lightning Bolt", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.damage, 2, "to a permanent too")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "a creature's ability is not a spell")


func test_benevolent_unicorn_shaves_its_own_controllers_spells_and_reduces_a_ping_to_nothing() -> void:
	put_battlefield(0, "Benevolent Unicorn")
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 18, "any spell, whoever's")
	cast("Kaervek's Torch", [TargetRef.player(1)], 1)
	assert_eq(g.players[1].life, 18, "1 - 1 = no damage at all (CR 614.7a)")


func test_two_benevolent_unicorns_each_apply_once() -> void:
	put_battlefield(1, "Benevolent Unicorn")
	put_battlefield(0, "Benevolent Unicorn")
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 19)


# --------------------------------------------------------------- Shadowbane --

func test_shadowbane_stops_one_black_event_to_you_and_your_creatures_and_pays_it_back() -> void:
	var p1 := seat(1)
	var pest := put_battlefield(0, "Pestilence")
	var mine := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	pestilence_pending(pest)
	p1.picks = ["Pestilence"]
	cast_only("Shadowbane", [], 0, 1)
	resolve_stack()
	assert_eq(bear.damage, 0, "your creature: prevented")
	assert_eq(g.players[1].life, 22, "you: prevented — and 1 + 1 black damage prevented is 2 life")
	assert_eq(mine.damage, 1, "not the opponent's creature")
	assert_eq(g.players[0].life, 19, "nor the opponent")
	pestilence_pending(pest)
	resolve_stack()
	assert_eq(g.players[1].life, 21, "the next event is a new one")
	assert_eq(bear.damage, 1)


func test_shadowbane_against_a_red_source_prevents_without_life() -> void:
	var p1 := seat(1)
	bolt_pending(TargetRef.player(1))
	p1.picks = ["Lightning Bolt"]
	cast_only("Shadowbane", [], 0, 1)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "prevented, and a red source pays nothing back")


# ------------------------------------------------------- Circle of Despair --

func test_circle_of_despair_sacrifices_a_creature_and_shields_a_creature() -> void:
	var p1 := seat(1)
	var circle := put_battlefield(1, "Circle of Despair")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	bolt_pending(TargetRef.card(giant))
	add_mana(1, Mtg.ManaColor.C)
	p1.picks = [bear, "Lightning Bolt"]
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.card(giant)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature is sacrificed as the cost")
	resolve_stack()
	assert_eq(giant.damage, 0, "the named Bolt's damage to the target is prevented")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_circle_of_despair_shields_a_player_too() -> void:
	var p1 := seat(1)
	var circle := put_battlefield(1, "Circle of Despair")
	put_battlefield(1, "Grizzly Bears")
	bolt_pending(TargetRef.player(1))
	add_mana(1, Mtg.ManaColor.C)
	p1.picks = ["Grizzly Bears", "Lightning Bolt"]
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


func test_circle_of_despair_needs_a_creature_to_sacrifice() -> void:
	var circle := put_battlefield(1, "Circle of Despair")
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, circle, 0, [TargetRef.player(1)]))


# ----------------------------------------------------------- Reflect Damage --

func test_reflect_damage_turns_a_bolt_on_its_caster() -> void:
	var p1 := seat(1)
	var bear := put_battlefield(1, "Grizzly Bears")
	bolt_pending(TargetRef.card(bear))
	p1.picks = ["Lightning Bolt"]
	cast_only("Reflect Damage", [], 0, 1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 17, "dealt to the source's controller instead")
	assert_eq(g.players[1].life, 20)


func test_reflect_damage_catches_any_victim_of_one_event_once() -> void:
	var p1 := seat(1)
	var pest := put_battlefield(0, "Pestilence")
	put_battlefield(0, "Grizzly Bears")
	pestilence_pending(pest)
	p1.picks = ["Pestilence"]
	cast_only("Reflect Damage", [], 0, 1)
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 17,
		"its 1 to each player and to its controller's own bear all hit its controller — and is not reflected again")
	pestilence_pending(pest)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the next time only")


# -------------------------------------------------------- Honorable Passage --

func test_honorable_passage_turns_red_damage_on_its_controller() -> void:
	var p1 := seat(1)
	var bear := put_battlefield(1, "Grizzly Bears")
	bolt_pending(TargetRef.card(bear))
	p1.picks = ["Lightning Bolt"]
	cast_only("Honorable Passage", [TargetRef.card(bear)], 0, 1)
	resolve_stack()
	assert_eq(bear.damage, 0, "prevented")
	assert_eq(g.players[0].life, 17, "a red source: Honorable Passage deals that much to its controller")


func test_honorable_passage_against_a_blue_source_only_prevents() -> void:
	var p1 := seat(1)
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	p1.picks = [sorcerer]
	cast_only("Honorable Passage", [TargetRef.player(1)], 0, 1)
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20, "not a red source")


func test_honorable_passage_covers_its_target_only() -> void:
	var p1 := seat(1)
	var bear := put_battlefield(1, "Grizzly Bears")
	bolt_pending(TargetRef.player(1))
	p1.picks = ["Lightning Bolt"]
	cast_only("Honorable Passage", [TargetRef.card(bear)], 0, 1)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the Bolt went to the player, not the shielded bear")
	assert_eq(g.players[0].life, 20)
	assert_eq(g.damage_effects.size(), 1, "an unused shield is not spent (CR 609.7b)")


## CR 616.1: a Circle of Protection: Red and an Honorable Passage both
## waiting for the same Bolt — the damaged player picks which applies
## first, and the other one is left unspent (it prevented nothing).
func test_cr_616_1_the_damaged_player_orders_passage_against_a_circle() -> void:
	for passage_first in [true, false]:
		_fresh()
		var p1 := seat(1)
		var cop := put_battlefield(1, "Circle of Protection: Red")
		bolt_pending(TargetRef.player(1))
		add_mana(1, Mtg.ManaColor.C)
		p1.picks = ["Lightning Bolt", "Lightning Bolt"]
		assert_ok(g.activate_ability(1, cop, 0))
		cast_only("Honorable Passage", [TargetRef.player(1)], 0, 1)
		p1.options = ["Honorable" if passage_first else "Circle"]
		resolve_stack()
		assert_true(p1.asked.size() >= 1 and p1.asked[-1].contains("Honorable Passage") \
			and p1.asked[-1].to_lower().contains("circle"), "the player was asked: %s" % str(p1.asked))
		assert_eq(g.players[1].life, 20, "prevented either way")
		if passage_first:
			assert_eq(g.players[0].life, 17, "the Passage prevented it: 3 back at the Bolt's controller")
			assert_eq(g.players[1].prevention_shield_filters.size(), 1, "the Circle's shield was not used")
		else:
			assert_eq(g.players[0].life, 20, "the Circle prevented it: the Passage did nothing")
			assert_eq(g.damage_effects.size(), 1, "the Passage's shield is still waiting")


## CR 616.1 again, Shadowbane against a Circle of Protection: Black over one
## Pestilence activation — Shadowbane first gains the life, the Circle first
## leaves Shadowbane standing.
func test_cr_616_1_the_damaged_player_orders_shadowbane_against_a_circle() -> void:
	for bane_first in [true, false]:
		_fresh()
		var p1 := seat(1)
		var pest := put_battlefield(0, "Pestilence")
		put_battlefield(0, "Grizzly Bears")
		var cop := put_battlefield(1, "Circle of Protection: Black")
		pestilence_pending(pest)
		add_mana(1, Mtg.ManaColor.C)
		p1.picks = ["Pestilence", "Pestilence"]
		assert_ok(g.activate_ability(1, cop, 0))
		cast_only("Shadowbane", [], 0, 1)
		p1.options = ["Shadowbane" if bane_first else "Circle"]
		resolve_stack()
		assert_eq(g.players[0].life, 19)
		if bane_first:
			assert_eq(g.players[1].life, 21, "Shadowbane prevented it and paid it back")
			assert_eq(g.players[1].prevention_shield_filters.size(), 1, "the Circle is unused")
		else:
			assert_eq(g.players[1].life, 20, "the Circle prevented it, nothing gained")
			assert_eq(g.players[1].prevention_shield_filters.size(), 0)
			assert_eq(g.damage_effects.size(), 1, "Shadowbane still waits for the next event")


# ----------------------------------------------------------- Righteous Aura --

func test_righteous_aura_pays_two_life_to_stop_the_named_source() -> void:
	var p1 := seat(1)
	var aura := put_battlefield(1, "Righteous Aura")
	bolt_pending(TargetRef.player(1))
	add_mana(1, Mtg.ManaColor.W)
	p1.picks = ["Lightning Bolt"]
	assert_ok(g.activate_ability(1, aura, 0))
	assert_eq(g.players[1].life, 18, "2 life paid as the cost")
	resolve_stack()
	assert_eq(g.players[1].life, 18, "and the Bolt prevented")


func test_righteous_aura_covers_only_you() -> void:
	var p1 := seat(1)
	var aura := put_battlefield(1, "Righteous Aura")
	var bear := put_battlefield(1, "Grizzly Bears")
	bolt_pending(TargetRef.card(bear))
	add_mana(1, Mtg.ManaColor.W)
	p1.picks = ["Lightning Bolt"]
	assert_ok(g.activate_ability(1, aura, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "\"to you\" — not to your creature")


func test_righteous_aura_cannot_pay_life_it_does_not_have() -> void:
	var aura := put_battlefield(1, "Righteous Aura")
	g.adjust_life(1, -19)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(1, aura, 0))


# ----------------------------------------------------- the 1997 window --

## The Fifth Edition profile: the waiting combat damage of a RED attacker,
## and Honorable Passage cast in the damage prevention step names it —
## prevented as it lands, and the attacker's controller takes it instead.
func test_1997_window_honorable_passage_after_the_damage_is_dealt() -> void:
	var p1 := seat(1)
	var giant := put_battlefield(0, "Hill Giant")
	var passage := give_hand(1, "Honorable Passage")
	to_the_1997_window(giant, p1)
	window_priority(1)
	fund(1, passage)
	assert_ok(g.cast_spell(1, passage, [TargetRef.player(1)]))
	close_window()
	assert_eq(g.players[1].life, 20, "the waiting 3 was prevented as it landed")
	assert_eq(g.players[0].life, 17, "and turned on the red attacker's controller")


## The modern profile has no such step: the same Passage is cast BEFORE the
## damage (declare blockers) and does the same.
func test_modern_profile_honorable_passage_before_the_damage() -> void:
	var p1 := seat(1)
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_ok(g.pass_priority(0))
	p1.picks = [giant]
	cast_only("Honorable Passage", [TargetRef.player(1)], 0, 1)
	resolve_stack()
	assert_false(g.awaiting_damage_prevention)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 17)


func test_1997_window_shadowbane_and_circle_of_despair() -> void:
	var p1 := seat(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var bane := give_hand(1, "Shadowbane")
	to_the_1997_window(wurm, p1)
	window_priority(1)
	fund(1, bane)
	assert_ok(g.cast_spell(1, bane, []))
	close_window()
	assert_eq(g.players[1].life, 20, "Shadowbane in the window: the Wurm's 6 prevented, green pays nothing")


func test_1997_window_circle_of_despair_is_a_prevention_ability() -> void:
	var p1 := seat(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var circle := put_battlefield(1, "Circle of Despair")
	var bear := put_battlefield(1, "Grizzly Bears")
	to_the_1997_window(wurm, p1)
	window_priority(1)
	add_mana(1, Mtg.ManaColor.C)
	p1.picks = [bear, wurm]
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.player(1)]))
	close_window()
	assert_eq(g.players[1].life, 20)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


## Righteous Aura is a Circle of Protection's shape: in the 1997 window it
## may target the waiting damage itself (its packet), as the Circles do.
func test_1997_window_righteous_aura_targets_the_waiting_packet() -> void:
	var p1 := seat(1)
	var giant := put_battlefield(0, "Hill Giant")
	var aura := put_battlefield(1, "Righteous Aura")
	to_the_1997_window(giant, p1)
	window_priority(1)
	var packet: DamagePacket = g.damage_pending[0]
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(1, aura, 0, [TargetRef.damage(packet)]))
	close_window()
	assert_eq(g.players[1].life, 18, "2 life paid, the 3 prevented")


## Reflect Damage is a REDIRECTION — the 1997 window's other legal kind
## ("prevent, heal, or redirect damage").
func test_1997_window_reflect_damage_turns_the_waiting_damage() -> void:
	var p1 := seat(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var reflect := give_hand(1, "Reflect Damage")
	to_the_1997_window(wurm, p1)
	window_priority(1)
	fund(1, reflect)
	assert_ok(g.cast_spell(1, reflect, []))
	close_window()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 14, "the Wurm's 6 went to its controller")


## A Bolt's damage waits in the window; Benevolent Unicorn's static still
## knows it as a SPELL's damage when it lands.
func test_1997_window_benevolent_unicorn_shaves_a_waiting_bolt() -> void:
	var p1 := seat(1)
	g.rules.damage_prevention_window = true
	p1.window = true
	put_battlefield(1, "Benevolent Unicorn")
	give_hand(1, "Shadowbane")   # something to do in the window
	cast_only("Lightning Bolt", [TargetRef.player(1)])
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_true(g.awaiting_damage_prevention, "the Bolt's damage waits")
	close_window()
	assert_eq(g.players[1].life, 18, "3 - 1, as it landed")


## Soul Echo's replacement meets the waiting damage as it lands.
func test_1997_window_soul_echo_replaces_landing_damage() -> void:
	var p1 := seat(1)
	var echo := cast("Soul Echo", [], 4)
	var giant := put_battlefield(1, "Hill Giant")
	p1.answers = [true]
	_to_upkeep_of(0)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	g.rules.damage_prevention_window = true
	var p0 := seat(0)
	p0.window = true
	give_hand(0, "Shadowbane")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	close_window()
	assert_eq(g.players[0].life, 20)
	assert_eq(int(echo.counters.get("echo", 0)), 1, "3 counters for the giant's 3")


## A non-prevention spell is still refused in the window.
func test_1997_window_refuses_a_burn_spell() -> void:
	var p1 := seat(1)
	var giant := put_battlefield(0, "Hill Giant")
	var bolt := give_hand(1, "Lightning Bolt")
	give_hand(1, "Shadowbane")
	to_the_1997_window(giant, p1)
	window_priority(1)
	fund(1, bolt)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]), "damage prevention")


# ------------------------------------------------------------- Lichenthrope --

func test_lichenthrope_takes_counters_instead_of_damage_and_sheds_one_each_upkeep() -> void:
	var lichen := put_battlefield(0, "Lichenthrope")
	cast("Lightning Bolt", [TargetRef.card(lichen)], 0, 0)
	assert_eq(lichen.damage, 0, "no damage marked")
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 3)
	assert_eq([lichen.cur_power, lichen.cur_toughness], [2, 2])
	advance_to_next_turn()
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 3, "not on the opponent's upkeep")
	advance_to_next_turn()
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 2, "your upkeep: one removed")
	assert_eq([lichen.cur_power, lichen.cur_toughness], [3, 3])


func test_lichenthrope_dies_to_counters_not_damage() -> void:
	var lichen := put_battlefield(1, "Lichenthrope")
	var wurm := put_battlefield(0, "Craw Wurm")
	g.deal_damage(wurm, TargetRef.card(lichen), 4)
	assert_eq(lichen.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([lichen.cur_power, lichen.cur_toughness, lichen.damage], [1, 1, 0], "a 1/1 with nothing marked")
	g.deal_damage(wurm, TargetRef.card(lichen), 1)
	assert_eq(lichen.zone, Mtg.Zone.GRAVEYARD, "five -1/-1 counters on a 5/5: toughness 0, not lethal damage")


func test_lichenthrope_controller_orders_counters_against_a_prevention_pool() -> void:
	var p0 := seat(0)
	var lichen := put_battlefield(0, "Lichenthrope")
	lichen.prevention = 2
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(lichen), 3)
	assert_eq(p0.asked.size(), 1, "two replacements: its controller orders them")
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 1, "the default: the pool first, the rest as counters")


# ------------------------------------------------------------- Ogre Enforcer --

func test_ogre_enforcer_survives_lethal_damage_split_between_sources() -> void:
	var ogre := put_battlefield(1, "Ogre Enforcer")
	cast("Lightning Bolt", [TargetRef.card(ogre)])
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(ogre)]))
	resolve_stack()
	assert_eq(ogre.damage, 4)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "4 on a 4/4, but no one source dealt 4")
	g.deal_damage(put_battlefield(1, "Craw Wurm"), TargetRef.card(ogre), 4)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "one source's lethal share")


func test_ogre_enforcer_blocked_by_two_bears_survives_the_combat() -> void:
	var ogre := put_battlefield(0, "Ogre Enforcer")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	run_combat([ogre.id], {a.id: ogre.id, b.id: ogre.id})
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "2 + 2 from two sources")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


func test_ogre_enforcer_still_dies_to_destroy_and_zero_toughness() -> void:
	var ogre := put_battlefield(1, "Ogre Enforcer")
	cast("Terror", [TargetRef.card(ogre)])
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Kaervek's Torch --

func test_kaerveks_torch_with_x_zero_deals_nothing() -> void:
	cast("Kaervek's Torch", [TargetRef.player(1)], 0)
	assert_eq(g.players[1].life, 20)


func test_kaerveks_torch_deals_x_to_any_target() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	cast("Kaervek's Torch", [TargetRef.player(1)], 4)
	assert_eq(g.players[1].life, 16)
	cast("Kaervek's Torch", [TargetRef.card(giant)], 3)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_kaerveks_torch_taxes_a_spell_that_targets_it() -> void:
	var torch := cast_only("Kaervek's Torch", [TargetRef.player(1)], 2)
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(1, counter, [TargetRef.card(torch)]))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(torch)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "countered, after paying {2} more")


func test_kaerveks_torch_does_not_tax_a_spell_aimed_elsewhere() -> void:
	cast_only("Kaervek's Torch", [TargetRef.player(1)], 1)
	var bolt := cast_only("Lightning Bolt", [TargetRef.player(1)], 0, 0)
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bolt)]))  # the Bolt is not the Torch
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# ---------------------------------------------------------- Torrent of Lava --

func test_torrent_of_lava_burns_creatures_without_flying() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var mine := put_battlefield(0, "Hill Giant")
	cast("Torrent of Lava", [], 3)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "each creature — the caster's too")
	assert_eq(angel.damage, 0, "a flyer is untouched")
	assert_eq(g.players[1].life, 20, "creatures only")


func test_torrent_of_lava_grants_every_creature_a_shield_while_on_the_stack() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var angel := put_battlefield(1, "Serra Angel")
	var before := wall.cur_activated_abilities.size()
	cast_only("Torrent of Lava", [], 4)
	assert_eq(wall.cur_activated_abilities.size(), before + 1, "granted while on the stack")
	assert_eq(angel.cur_activated_abilities.size(), 1, "each creature, a flyer included")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, wall, before))
	assert_true(wall.tapped)
	resolve_stack()
	assert_eq(wall.damage, 3, "4 from the Torrent, 1 prevented")
	assert_eq(wall.cur_activated_abilities.size(), before, "gone with the spell")


func test_torrent_of_lava_shield_does_not_stop_other_damage() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var before := wall.cur_activated_abilities.size()
	cast_only("Torrent of Lava", [], 2)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, wall, before))
	resolve_stack()
	assert_eq(wall.damage, 1)
	cast("Lightning Bolt", [TargetRef.card(wall)])
	assert_eq(wall.damage, 4, "the shield was keyed to Torrent of Lava, and used")


# --------------------------------------------------------------- Soul Echo --

func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)


func test_soul_echo_enters_with_x_counters_and_you_do_not_lose_at_zero() -> void:
	var echo := cast("Soul Echo", [], 2)
	assert_eq(echo.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(echo.counters.get("echo", 0)), 2)
	g.adjust_life(0, -25)
	g.check_state_based_actions()
	assert_false(g.players[0].has_lost, "0 or less life does not lose the game")
	assert_false(g.game_over)


func test_soul_echo_opponent_chooses_damage_removes_counters_until_next_upkeep() -> void:
	var p1 := seat(1)
	var echo := cast("Soul Echo", [], 3)
	var giant := put_battlefield(1, "Hill Giant")
	p1.answers = [true]
	_to_upkeep_of(0)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(giant, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 20, "the damage became counter removal")
	assert_eq(int(echo.counters.get("echo", 0)), 1)
	advance_to_next_turn()
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 20, "still replaced on the opponent's turn, all of it")
	assert_eq(int(echo.counters.get("echo", 0)), 0)
	p1.answers = [true]
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(echo.zone, Mtg.Zone.GRAVEYARD, "no echo counters: sacrificed")
	assert_true(g.damage_effects.is_empty(), "the replacement ended with the upkeep")


func test_soul_echo_with_x_zero_goes_at_the_first_upkeep() -> void:
	var echo := cast("Soul Echo", [], 0)
	assert_eq(int(echo.counters.get("echo", 0)), 0)
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(echo.zone, Mtg.Zone.GRAVEYARD)


func test_soul_echo_opponent_declines_and_damage_is_dealt_as_usual() -> void:
	var p1 := seat(1)
	var echo := cast("Soul Echo", [], 2)
	var giant := put_battlefield(1, "Hill Giant")
	p1.answers = [false]
	_to_upkeep_of(0)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17)
	assert_eq(int(echo.counters.get("echo", 0)), 2)


func test_soul_echo_gone_the_player_at_zero_loses() -> void:
	var echo := cast("Soul Echo", [], 1)
	g.adjust_life(0, -20)
	g.check_state_based_actions()
	assert_false(g.players[0].has_lost)
	cast("Disenchant", [TargetRef.card(echo)], 0, 0)
	assert_eq(echo.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].has_lost, "the Echo gone, 0 life loses")
