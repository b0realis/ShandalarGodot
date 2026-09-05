extends GameTest
## "A source of your choice" and "you may choose new targets for the copy"
## — the 2026-09-02 fidelity lifts that rest on two shared engine pieces:
## MtgGame.damage_sources / rank_damage_sources (the Circles of Protection,
## Reverse Damage, Jade Monolith, Nova Pentacle all NAME one source now,
## and the one named is the only one shielded) and
## MtgGame.offer_new_targets (Fork's and Chain Lightning's copies are
## re-aimed by their controller, slot by slot). Each is pinned on what the
## old rule denied it: a seat that names the OTHER source, or aims the
## copy somewhere the fixed rule never would, and gets it.


## A seat that answers by script: OPTION questions by label, CARD questions
## by instance id (-1 declines), and records everything it was asked.
class Seat extends DecisionAgent:
	var labels: Array = []
	var cards: Array = []
	var yes := true
	var asked: Array = []       # [prompt, options] per OPTION question
	var offered: Array = []     # [prompt, [ids]] per CARD question
	var yes_no_prompts: Array = []

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append([prompt, options.duplicate()])
		if labels.is_empty():
			return hint
		var wanted := String(labels.pop_front())
		var at := options.find(wanted)
		return at if at >= 0 else hint

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		var ids: Array = []
		for inst in candidates:
			ids.append(inst.id)
		offered.append([prompt, ids])
		if cards.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want := int(cards.pop_front())
		if want == -1:
			return null
		for inst in candidates:
			if inst.id == want:
				return inst
		return null if candidates.is_empty() else candidates[0]

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		yes_no_prompts.append(prompt)
		return yes


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


func _seat(pid: int) -> Seat:
	var seat := Seat.new()
	g.set_agent(pid, seat)
	return seat


## Their two red attackers swing at us; nobody blocks; priority is ours in
## the declare-blockers step. Returns [giant, ogre].
func _two_red_attackers_unblocked() -> Array:
	var giant := put_battlefield(1, "Hill Giant")   # 3/3, red
	var ogre := put_battlefield(1, "Gray Ogre")     # 2/2, red
	advance_to_next_turn()                          # their turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id, ogre.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))                   # the attacker passes to us
	assert_eq(g.priority_player, 0)
	return [giant, ogre]


# ------------------------------------------------ Circles of Protection --
#
# "The next time a red source OF YOUR CHOICE would deal damage to you this
# turn, prevent that damage." — one source, named as the ability resolves.

func test_a_circle_shields_only_the_red_source_it_names() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var pair := _two_red_attackers_unblocked()
	var giant: CardInstance = pair[0]
	var ogre: CardInstance = pair[1]
	var seat := _seat(0)
	seat.cards = [ogre.id]                          # not the one the hint leads with
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_eq(seat.offered.size(), 1, "one question: which red source")
	assert_eq(String(seat.offered[0][0]), "Circle of Protection: Red: Select a red source.")
	assert_eq(seat.offered[0][1], [giant.id, ogre.id],
		"the bigger unblocked attacker leads the list — the heuristic's pick")
	assert_true(_log_has("shields %s against Gray Ogre" % g.players[0].player_name))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 17, "the Ogre's two were prevented; the Giant's three landed")
	assert_true(g.players[0].prevention_shield_filters.is_empty(), "one shot, spent")


func test_the_heuristic_names_the_biggest_unblocked_attacker() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Red")
	_two_red_attackers_unblocked()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 18, "the Giant's three were prevented; the Ogre's two landed")


func test_a_circle_with_no_red_source_in_sight_shields_nothing() -> void:
	# Activated BEFORE the Bolt is cast: there is no red source to name,
	# so nothing is shielded (CR 608.2) — the reason a Circle is activated
	# in response.
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_true(_log_has("Circle of Protection: Red: nothing to name as a red source, nothing is shielded"),
		"nothing to name")
	assert_true(g.players[0].prevention_shield_filters.is_empty())
	assert_true(g.players[0].prevention_shields.is_empty())
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the Bolt landed: the Circle had named nothing")


func test_a_circle_in_response_names_the_bolt_on_the_stack() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var giant := put_battlefield(1, "Hill Giant")   # a red permanent, also a candidate
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))                   # the Circle resolves first
	assert_eq(g.stack.size(), 1, "the Bolt is still waiting")
	assert_eq(seat.offered.size(), 1)
	assert_eq(seat.offered[0][1], [bolt.id, giant.id],
		"the spell aimed at us leads; the Giant on the battlefield follows")
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the named Bolt was prevented")



func test_circle_of_protection_artifacts_names_one_artifact_source() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Artifacts")
	var rod := put_battlefield(1, "Rod of Ruin")
	var golem := put_battlefield(1, "Obsianus Golem")   # an artifact creature: also a candidate
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	seat.cards = [golem.id]                              # names the wrong one on purpose
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_eq(String(seat.offered[0][0]), "Circle of Protection: Artifacts: Select an artifact source.")
	assert_eq(seat.offered[0][1], [rod.id, golem.id],
		"the Rod, whose ability is aimed at us, leads")
	assert_eq(g.players[0].life, 19, "the Golem was named, so the Rod's ping landed")


# ---------------------------------------------------------- Reverse Damage --
#
# `@REVERSE_DAMAGE` (Program/prompts.txt:753): "Select a card that has
# damaged you." — one source, named as the spell resolves.

func test_reverse_damage_names_the_bolt_in_response() -> void:
	var spell := give_hand(0, "Reverse Damage")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(String(seat.offered[0][0]), "Select a card that has damaged you.")
	assert_eq(seat.offered[0][1], [bolt.id, giant.id], "the Bolt aimed at us leads")
	assert_eq(g.players[0].life, 23, "the Bolt's three came back as life")
	assert_true(g.players[0].reverse_damage_sources.is_empty(), "one shot")


func test_reverse_damage_only_answers_the_source_it_named() -> void:
	var spell := give_hand(0, "Reverse Damage")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	seat.cards = [giant.id]
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the Giant was named, so the Bolt landed")
	assert_eq(g.players[0].reverse_damage_sources, [giant.id], "and the Giant is still watched")


# ----------------------------------------------------------- Jade Monolith --

func _bear_blocked_by_wurm() -> Array:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: bear.id}))
	return [bear, wurm]


func test_jade_monolith_leads_with_the_creature_it_is_fighting() -> void:
	var monolith := put_battlefield(0, "Jade Monolith")
	var giant := put_battlefield(1, "Hill Giant")      # not in this fight
	var pair := _bear_blocked_by_wurm()
	var bear: CardInstance = pair[0]
	var wurm: CardInstance = pair[1]
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(String(seat.offered[0][0]), "Jade Monolith: Select a source of damage to Grizzly Bears.")
	assert_eq(seat.offered[0][1].slice(0, 2), [wurm.id, giant.id],
		"the blocker leads, then the other side's other creature")
	assert_eq(bear.damage_redirect_sources, [wurm.id])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 14, "all six points were redirected")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_jade_monolith_only_redirects_the_source_it_named() -> void:
	var monolith := put_battlefield(0, "Jade Monolith")
	var giant := put_battlefield(1, "Hill Giant")
	var pair := _bear_blocked_by_wurm()
	var bear: CardInstance = pair[0]
	var seat := _seat(0)
	seat.cards = [giant.id]                              # the wrong creature
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "the Wurm was not the named source")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "so the Bears died")


func test_jade_monolith_in_response_leads_with_the_bolt() -> void:
	var monolith := put_battlefield(0, "Jade Monolith")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(seat.offered[0][1][0], bolt.id, "the Bolt aimed at the Bears leads")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the bear is untouched")
	assert_eq(g.players[0].life, 17, "we took it instead")


# ------------------------------------------------------ the shared ranking --

func test_damage_sources_are_ranked_by_threat_to_the_victim() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var rod := put_battlefield(1, "Rod of Ruin")
	var ogre := put_battlefield(1, "Gray Ogre")
	var giant := put_battlefield(1, "Hill Giant")
	var ranked := g.damage_sources(Callable(), TargetRef.player(0))
	var ids: Array = []
	for inst in ranked:
		ids.append(inst.id)
	assert_eq(ids, [giant.id, ogre.id, rod.id, bears.id],
		"their creatures by power, their other permanents, then our own")
	var red_only := g.damage_sources(func(inst: CardInstance) -> bool:
		return (inst.cur_colors & Mtg.ManaColor.R) != 0)
	assert_eq(red_only.size(), 2, "the filter narrows the list")


# --------------------------------------------------------------------- Fork --
#
# Duel.hlp, Fork: "you choose the copy's targets" ... "the controller of
# the copy must use the same number of targets the original spell did".

func _their_bolt_at(target: TargetRef) -> CardInstance:
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [target]))
	assert_ok(g.pass_priority(1))
	return bolt


func test_fork_lets_its_caster_aim_the_copy_anywhere_legal() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var fork := give_hand(0, "Fork")
	var bolt := _their_bolt_at(TargetRef.player(0))
	var seat := _seat(0)
	seat.labels = ["Grizzly Bears"]
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "one slot, one question")
	assert_eq(String(seat.asked[0][0]), "Lightning Bolt: Select any target for the copy.")
	assert_eq(seat.asked[0][1], [g.players[1].player_name, g.players[0].player_name, "Grizzly Bears"],
		"the opponent's face leads; every legal target is on the list")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the copy went where it was aimed")
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 17, "the original still hit us")
	assert_true(_log_has("Lightning Bolt's copy is aimed at Grizzly Bears"))


func test_forked_copy_leads_with_the_opponents_face_even_off_a_creature_bolt() -> void:
	# The old fixed rule kept a creature target — re-bolting your own
	# creature. The hint now leads with their face whenever a player may
	# be named, and the heuristic takes it.
	var bears := put_battlefield(0, "Grizzly Bears")
	var fork := give_hand(0, "Fork")
	var bolt := _their_bolt_at(TargetRef.card(bears))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the original still killed the Bears")
	assert_eq(g.players[1].life, 17, "and the copy hit them")
	assert_eq(g.players[0].life, 20)


func test_fork_asks_a_card_question_when_only_creatures_are_legal() -> void:
	var their_bears := put_battlefield(1, "Grizzly Bears")
	var our_giant := put_battlefield(0, "Hill Giant")
	var fork := give_hand(0, "Fork")
	var growth := give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(their_bears)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	seat.cards = [our_giant.id]
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(seat.asked.size(), 0, "no OPTION question")
	assert_eq(seat.offered.size(), 1, "a CARD question: every candidate is a creature")
	assert_eq(String(seat.offered[0][0]), "Giant Growth: Select target creature for the copy.")
	assert_eq(seat.offered[0][1], [their_bears.id, our_giant.id],
		"the original's target leads when no player may be named")
	assert_eq(our_giant.cur_power, 6, "our Giant got the copy's +3/+3")
	assert_eq(their_bears.cur_power, 5, "their Bears got the original's")


func test_fork_keeps_a_slot_with_a_single_legal_target_without_asking() -> void:
	var their_bears := put_battlefield(1, "Grizzly Bears")
	var fork := give_hand(0, "Fork")
	var growth := give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(their_bears)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(seat.offered.size(), 0, "the only creature is the only candidate: no question")
	assert_eq(their_bears.cur_power, 8, "both copies landed on it")


func test_forked_copy_cannot_be_aimed_at_protection_from_red() -> void:
	var fork := give_hand(0, "Fork")
	var warded := put_battlefield(1, "Grizzly Bears")
	var ward := give_hand(1, "Red Ward")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()                               # their main phase
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, ward, [TargetRef.card(warded)]))
	resolve_stack()
	assert_true((warded.cur_protection & Mtg.ManaColor.R) != 0, "the Bears have protection from red")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var seat := _seat(0)
	seat.labels = ["Grizzly Bears"]                      # asks for what it cannot have
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(seat.asked[0][1], [g.players[1].player_name, g.players[0].player_name],
		"the copy is red, so the warded Bears are not on its list")
	assert_eq(warded.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 17, "the stale answer fell back to the leading entry")


# ---------------------------------------------------------- Chain Lightning --

func test_chain_lightning_copy_may_be_aimed_at_a_creature() -> void:
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Mountain")
	var our_bears := put_battlefield(0, "Grizzly Bears")
	var chain := give_hand(0, "Chain Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	var seat := _seat(1)
	seat.labels = ["Grizzly Bears"]
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, chain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(seat.yes_no_prompts, ["Pay {R}{R} to copy Chain Lightning?"])
	assert_eq(seat.asked.size(), 1)
	assert_eq(String(seat.asked[0][0]), "Chain Lightning: Select any target for the copy.")
	assert_eq(seat.asked[0][1][0], g.players[0].player_name,
		"the player who passed it on leads the list")
	assert_eq(g.players[1].life, 17, "the original hit them")
	assert_eq(our_bears.zone, Mtg.Zone.GRAVEYARD, "the copy went where they aimed it")
	assert_eq(g.players[0].life, 20)
