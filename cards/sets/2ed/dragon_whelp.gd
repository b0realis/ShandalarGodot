extends CardScript
## Dragon Whelp — {2}{R}{R} — Creature — Dragon — 2/3 — (2ed, uncommon)
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn. If this ability
##         has been activated four or more times this turn, sacrifice this
##         creature at the beginning of the next end step.
##
## Implementation: firebreathing with a fuse. The breath count is card-local
## and stamped with the turn it belongs to — "four or more times THIS TURN"
## means a breath a turn is harmless forever (CardInstance.memory survives
## the turn, so the turn number has to travel with the count). The fourth
## breath schedules a delayed end-step SACRIFICE, which regeneration and
## indestructible cannot stop (CR 701.17).


func build() -> CardData:
	return CardData.new("Dragon Whelp", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new("{R}", false, [WhelpBreathEffect.new()],
			"{R}: This creature gets +1/+0 until end of turn. If this ability has been activated four or more times this turn, sacrifice this creature at the beginning of the next end step.")) \
		.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn. If this ability has been activated four or more times this turn, sacrifice this creature at the beginning of the next end step.")


class WhelpBreathEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(source.id, 1, 0)
		game.recalculate()
		# The count resets with the turn: nothing else clears card memory
		# between turns, so the turn number is stored beside it.
		var burns := 1
		if int(source.memory.get("breaths_turn", -1)) == game.turn_number:
			burns = int(source.memory.get("breaths", 0)) + 1
		source.memory["breaths"] = burns
		source.memory["breaths_turn"] = game.turn_number
		if burns >= 4:
			game.doom_at_next_end_step(source, false, false, true)

	func describe() -> String:
		return "gets +1/+0 until end of turn; the fourth breath is fatal"
