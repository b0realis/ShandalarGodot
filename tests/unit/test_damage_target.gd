extends GameTest
## DAMAGE AS A TARGETABLE OBJECT (docs/duel-todo.md §6.8 slice 3, §6.20b).
##
## `Duel.hlp`, topic **Using Land**: *"If the effect is a targeted one
## (damage prevention, for example, WHICH TARGETS DAMAGE), you also need to
## choose a target. When you're prompted, click on any valid target — a
## card, A DAMAGE MARKER, or whatever."* And the Circle of Protection
## ruling: *"May only be used during damage prevention, as it targets
## PACKETS of the appropriate damage. However, you may use the Circle on
## the same damage more than once."*
##
## Two rulesets again: with the fork off there are never any packets, the
## Circle takes no target, and it puts up the one-shot colour shield it
## always did.


class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func _arm(pid: int) -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(pid, Duelist.new())


## Attack with [param attackers], stopping inside the open window.
func _attack_into_the_window(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the window is open")


func _end_window() -> void:
	while g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))


# ------------------------------------------------------------ the target ref --

func test_two_different_packets_are_not_the_same_target() -> void:
	# The bug the audit found: every damage ref carries instance_id == -1,
	# so the three hand-written identity comparisons in the codebase read
	# two DIFFERENT packets as the same target. TargetRef.same_object is
	# the one place the union is compared now.
	var one := DamagePacket.new()
	one.id = 7
	var two := DamagePacket.new()
	two.id = 8
	var a := TargetRef.damage(one)
	var b := TargetRef.damage(two)
	assert_false(a.same_object(b), "different damage, different target")
	assert_true(a.same_object(TargetRef.damage(one)), "the same damage")
	assert_false(a.same_object(TargetRef.player(0)))
	assert_false(TargetRef.player(0).same_object(a))
	assert_eq(a.instance_id, -1, "it is not a card ref")
	assert_false(a.is_player, "and not a player ref")


func test_damage_is_only_a_legal_target_inside_a_window() -> void:
	var spec := TargetSpec.damage()
	var wurm := put_battlefield(0, "Craw Wurm")
	assert_eq(spec.legal_targets(g, wurm).size(), 0,
		"no window, no packets, nothing to point at")
	_arm(1)
	put_battlefield(1, "Circle of Protection: Green")
	_attack_into_the_window([wurm.id])
	assert_eq(spec.legal_targets(g, wurm).size(), 1, "one packet is waiting")
	# A packet that never existed is `,where` — the same word the original
	# uses for a card in the wrong zone.
	var ghost := TargetRef.damage(DamagePacket.new())
	assert_eq(spec.refusal_reason(g, ghost, wurm), "where")
	# Damage offered where a creature is wanted, and the other way round.
	assert_eq(TargetSpec.creature().refusal_reason(
		g, TargetRef.damage(g.damage_pending[0]), wurm), "can't target this")
	assert_eq(spec.refusal_reason(g, TargetRef.card(wurm), wurm),
		"can't target this")


# ----------------------------------------------------- the Circle, both ways --

func test_a_circle_with_no_window_puts_up_its_shield() -> void:
	# The MODERN default. No packets exist, so the Circle's optional damage
	# target is simply not taken and the ability must still resolve — an
	# ability that took no target has not "lost all its targets".
	var circle := put_battlefield(1, "Circle of Protection: Green")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, circle, 0))
	resolve_stack()
	assert_eq(g.players[1].prevention_shield_filters.size(), 1,
		"a shield went up, naming the Wurm")
	run_combat([wurm.id])
	assert_eq(g.players[1].life, 20, "and it ate the Wurm")


func test_a_circle_in_the_window_answers_ONE_packet() -> void:
	# Two green attackers are two packets, and the Circle names one of
	# them — which is the difference between "any green source" and the
	# 1997 "this damage".
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")        # 6/4, green
	var bear := put_battlefield(0, "Grizzly Bears")    # 2/2, green
	var circle := put_battlefield(1, "Circle of Protection: Green")
	_attack_into_the_window([wurm.id, bear.id])
	assert_eq(g.damage_pending.size(), 2, "two sources, two packets")
	var big: DamagePacket = g.damage_pending[0] if g.damage_pending[0].amount == 6 \
		else g.damage_pending[1]
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.damage(big)]))
	resolve_stack()
	assert_eq(big.remaining(), 0, "the Wurm's six are prevented")
	_end_window()
	assert_eq(g.players[1].life, 18, "the Bears' two still landed")
	assert_eq(g.players[1].prevention_shield_filters.size(), 0,
		"no shield was created — it named the damage instead")


func test_a_circle_may_be_used_on_the_same_damage_twice() -> void:
	# The ruling's own second sentence: "However, you may use the Circle on
	# the same damage more than once." A packet with nothing left is still
	# a legal target; the second use simply takes nothing.
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var circle := put_battlefield(1, "Circle of Protection: Green")
	_attack_into_the_window([wurm.id])
	var packet: DamagePacket = g.damage_pending[0]
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.damage(packet)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))   # the window is still open; hand it back
	assert_ok(g.activate_ability(1, circle, 0, [TargetRef.damage(packet)]))
	resolve_stack()
	assert_eq(packet.prevented, 6, "still six, not twelve")
	_end_window()
	assert_eq(g.players[1].life, 20)


func test_a_circle_cannot_name_damage_of_the_wrong_colour() -> void:
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")            # green
	var circle := put_battlefield(1, "Circle of Protection: Red")
	give_hand(1, "Healing Salve")     # so the window opens at all
	_attack_into_the_window([wurm.id])
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(
		g.activate_ability(1, circle, 0, [TargetRef.damage(g.damage_pending[0])]),
		"Illegal target")
