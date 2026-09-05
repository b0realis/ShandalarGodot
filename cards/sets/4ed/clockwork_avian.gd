extends CardScript
## Clockwork Avian — {5} — Artifact Creature — Bird — 0/4 — (4ed, rare)
## Oracle: Flying
##         This creature enters with four +1/+0 counters on it.
##         At end of combat, if this creature attacked or blocked this
##         combat, remove a +1/+0 counter from it.
##         {X}, {T}: Put up to X +1/+0 counters on this creature. This
##         ability can't cause the total number of +1/+0 counters to be
##         greater than four. Activate only during your upkeep.
##
## Implementation: Clockwork Beast with wings and a rewind. The counters
## are plain "+1/+0" counters, which the continuous pipeline reads by name,
## and the rewind respects the four-counter ceiling.


func build() -> CardData:
	return CardData.new("Clockwork Avian", "{5}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 4) \
		.with_subtypes(["bird"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.with_enters_counters("+1/+0", 4) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_OF_COMBAT, _wind_down,
			"At end of combat, if this creature attacked or blocked this combat, remove a +1/+0 counter from it.",
			_fought)) \
		.activated(ActivatedAbility.new("{X}", true, [RewindEffect.new()],
			"{X}, {T}: Put up to X +1/+0 counters on this creature, to a maximum of four. Activate only during your upkeep.") \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("Flying\nThis creature enters with four +1/+0 counters on it.\nAt end of combat, if this creature attacked or blocked this combat, remove a +1/+0 counter from it.\n{X}, {T}: Put up to X +1/+0 counters on this creature. This ability can't cause the total number of +1/+0 counters on this creature to be greater than four. Activate only during your upkeep.")


static func _fought(_game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and (source.attacked_this_turn or source.blocked_this_turn) \
		and int(source.counters.get("+1/+0", 0)) > 0


static func _wind_down(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var left := int(source.counters.get("+1/+0", 0)) - 1
	if left <= 0:
		source.counters.erase("+1/+0")
	else:
		source.counters["+1/+0"] = left
	game.recalculate()
	game.check_state_based_actions()


class RewindEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var have := int(source.counters.get("+1/+0", 0))
		var room: int = maxi(4 - have, 0)
		var added: int = mini(x_value, room)
		if added > 0:
			game.add_counters(source, "+1/+0", added)

	func describe() -> String:
		return "puts up to X +1/+0 counters back on, to a maximum of four"
