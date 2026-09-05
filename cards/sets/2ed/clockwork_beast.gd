extends CardScript
## Clockwork Beast — {6} — Artifact Creature — Beast — 0/4 — (2ed, rare)
## Oracle: This creature enters with seven +1/+0 counters on it.
##         At end of combat, if this creature attacked or blocked this
##         combat, remove a +1/+0 counter from it.
##         {X}, {T}: Put up to X +1/+0 counters on this creature. This
##         ability can't cause the total number of +1/+0 counters to be
##         greater than seven. Activate only during your upkeep.
##
## Implementation: CardData.with_enters_counters plants the seven "+1/+0"
## counters (the continuous pipeline parses that name straight into a
## power bonus); an END_OF_COMBAT trigger spends one if it fought; and
## the {X} rewind ability tops it back up (capped at seven) during your
## upkeep — activate_ability takes an x_value exactly like cast_spell.


func build() -> CardData:
	return CardData.new("Clockwork Beast", "{6}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 4) \
		.with_subtypes(["beast"]) \
		.with_enters_counters("+1/+0", 7) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_OF_COMBAT, _wind_down,
			"At end of combat, if Clockwork Beast attacked or blocked this combat, "
			+ "remove a +1/+0 counter from it.",
			_fought)) \
		.activated(ActivatedAbility.new(
			"{X}", true, [RewindEffect.new()],
			"{X}, {T}: Put up to X +1/+0 counters on Clockwork Beast (maximum seven "
			+ "total). Activate only during your upkeep.") \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("This creature enters with seven +1/+0 counters on it.\nAt end of "
			+ "combat, if this creature attacked or blocked this combat, remove a "
			+ "+1/+0 counter from it.\n{X}, {T}: Put up to X +1/+0 counters on this "
			+ "creature. This ability can't cause the total number of +1/+0 counters "
			+ "on this creature to be greater than seven. Activate only during your upkeep.")


static func _fought(_game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return source.attacked_this_turn or source.blocked_this_turn


static func _wind_down(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var left := int(source.counters.get("+1/+0", 0)) - 1
	if left <= 0:
		source.counters.erase("+1/+0")
	else:
		source.counters["+1/+0"] = left
	game.recalculate()


class RewindEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		if source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var have := int(source.counters.get("+1/+0", 0))
		var room: int = maxi(7 - have, 0)
		var add: int = mini(x_value, room)
		if add > 0:
			game.add_counters(source, "+1/+0", add)

	func describe() -> String:
		return "winds the Beast back up by up to X counters (seven maximum)"
