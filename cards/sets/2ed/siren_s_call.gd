extends CardScript
## Siren's Call — {U} — Instant — (2ed, uncommon)
## Oracle: Cast this spell only during an opponent's turn, before attackers
##         are declared.
##         Creatures the active player controls attack this turn if able.
##         At the beginning of the next end step, destroy all non-Wall
##         creatures that player controls that didn't attack this turn.
##         Ignore this effect for each creature the player didn't control
##         continuously since the beginning of the turn.
##
## Implementation: the timing rider is CardData.castable_only_when; the
## conscription is Nettling Imp's per-creature flag
## (CardInstance.must_attack_this_turn) plus the engine's delayed
## "destroy at the next end step if it did not attack"
## (MtgGame.doom_at_next_end_step_if_it_did_not_attack).
##
## The snapshot is taken AT RESOLUTION, over exactly the creatures the
## clauses describe — this is the original's own reading. Duel.hlp, topic
## "Siren's Call": "All of that player's non-Wall creatures that do not have
## summoning sickness must attack this turn if able. At end of turn, destroy
## each of those creatures that did not attack this turn", with the ruling
## "Only the creatures the target controls during resolution of Siren's Call
## are forced to attack. Walls and creatures with summoning sickness are
## ignored by the effect."
##
## "Didn't control continuously since the beginning of the turn" IS
## summoning sickness here: the engine clears the flag in the active
## player's untap step and re-raises it on entering the battlefield and on
## every control change, so on the active player's own turn the flag means
## exactly "came under my control after this turn began".
##
## Walls are excused twice over — they are skipped here, and the engine
## excuses any must-attacker that cannot legally attack (CR 508.1d), so a
## Wall never deadlocks the declare-attackers step.


func build() -> CardData:
	return CardData.new("Siren's Call", "{U}", Mtg.CardType.INSTANT) \
		.castable_only_when(_opponents_turn_before_attackers) \
		.spell(CallEffect.new()) \
		.oracle("Cast this spell only during an opponent's turn, before attackers are declared.\n"
			+ "Creatures the active player controls attack this turn if able.\n"
			+ "At the beginning of the next end step, destroy all non-Wall creatures that player "
			+ "controls that didn't attack this turn. Ignore this effect for each creature the "
			+ "player didn't control continuously since the beginning of the turn.")


static func _opponents_turn_before_attackers(game: MtgGame, pid: int) -> String:
	if game.active_player == pid:
		return "cast Siren's Call only during an opponent's turn"
	if Mtg.STEP_ORDER.find(game.current_step()) \
			>= Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS):
		return "cast Siren's Call only before attackers are declared"
	return ""


class CallEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var ap := game.active_player
		for inst in game.players[ap].battlefield:
			if not inst.is_creature() or inst.has_subtype("wall"):
				continue
			if inst.summoning_sick:
				continue   # not controlled continuously since the turn began
			inst.must_attack_this_turn = true
			game.doom_at_next_end_step_if_it_did_not_attack(inst)

	func describe() -> String:
		return "the active player's non-Wall creatures attack this turn or die at end of turn"
