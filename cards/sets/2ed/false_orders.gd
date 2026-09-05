extends CardScript
## False Orders — {R} — Instant — (2ed, common)
## Oracle: Cast this spell only during the declare blockers step.
##         Remove target creature defending player controls from combat.
##         Creatures it was blocking that had become blocked by only that
##         creature this combat become unblocked. You may have it block an
##         attacking creature of your choice.
##
## Implementation: the target is pulled out of combat and immediately
## re-assigned to one of YOUR attackers, ignoring the usual restrictions,
## which is what "of your choice" means. The middle sentence is a printed
## EXCEPTION to CR 509.1h (a blocked creature normally stays blocked for
## the rest of the combat even with no blockers left), so the removal asks
## MtgGame.remove_from_combat for it explicitly: an attacker this creature
## alone was blocking really does become unblocked and connects.
##
## The printed scope is "target creature DEFENDING PLAYER controls" — the
## defending player is a property of the combat (CR 506.2), not of the
## caster, and the text never says "blocking". A defender that stayed home
## is therefore a legal target and can be dragged into the fight; removing
## it from combat is simply a no-op for it.
##
## "An attacking creature of YOUR choice" (lifted 2026-09-02; was "combat
## re-arrangement" in docs/simplified-cards.md): the caster picks the
## attacker through the DecisionAgent funnel — one OPTION per attacking
## creature plus "Don't block", since "you MAY have it block". The hint is
## the engine's old pick: your smallest attacker that isn't already being
## blocked (the one that dies to it least), or "Don't block" when you
## have none. Not a 1997 card (Duel.hlp has no entry, no exe function in
## Magic-trace.c); Manalink's card_false_orders (unlimited.c, Tier 3)
## asks "Select a new creature to block" after the removal, which is the
## prompt used here. The new block ignores the usual restrictions and
## requirements (CR 509.1 does not apply to a block an effect creates —
## "have it block" is the effect's own instruction), exactly as before.


static func _defending_players_creature(game: MtgGame, inst: CardInstance) -> bool:
	return inst.controller_id == game.opponent_of(game.active_player)


static func _during_declare_blockers(game: MtgGame, _pid: int) -> String:
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return "cast False Orders only during the declare blockers step"
	return ""


func build() -> CardData:
	var spec := TargetSpec.creature("target creature defending player controls")
	spec.with_game_filter(_defending_players_creature)
	return CardData.new("False Orders", "{R}", Mtg.CardType.INSTANT) \
		.castable_only_when(_during_declare_blockers) \
		.spell(FalseOrdersEffect.new(spec)) \
		.oracle("Cast this spell only during the declare blockers step.\nRemove target creature defending player controls from combat. Creatures it was blocking that had become blocked by only that creature this combat become unblocked. You may have it block an attacking creature of your choice.")


class FalseOrdersEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var blocker := game.find_instance(target.instance_id)
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD:
			return
		# "Creatures it was blocking that had become blocked by only that
		# creature this combat become unblocked" — the printed override of
		# CR 509.1h.
		game.remove_from_combat(blocker, true)
		# "You may have it block an attacking creature of your choice."
		var attackers: Array[CardInstance] = []
		var labels: Array[String] = []
		var best := -1
		for attacker_id in game.combat.attackers:
			var attacker := game.find_instance(attacker_id)
			if attacker == null or attacker.controller_id != controller:
				continue
			attackers.append(attacker)
			labels.append(attacker.data.card_name)
			# The hint: the smallest attacker that isn't already being
			# blocked — the one you least mind it landing on.
			if game.combat.blockers_of(attacker_id).is_empty() \
					and (best < 0 or attacker.cur_power < attackers[best].cur_power):
				best = attackers.size() - 1
		if attackers.is_empty():
			return
		labels.append("Don't block")
		var hint := best if best >= 0 else labels.size() - 1
		var pick: int = game.agents[controller].choose_option(game, controller,
			labels, "Select a new creature to block", hint)
		if pick < 0 or pick >= attackers.size():
			game.log_line("%s is left out of combat" % blocker.data.card_name)
			return
		game.set_block(blocker, attackers[pick])

	func describe() -> String:
		return "pulls a defender out of combat and re-points it at an attacker of your choice"
