extends CardScript
## Armageddon Clock — {6} — Artifact — (4ed, rare)
## Oracle: At the beginning of your upkeep, put a doom counter on this
##         artifact.
##         At the beginning of your draw step, this artifact deals damage
##         equal to the number of doom counters on it to each player.
##         {4}: Remove a doom counter from this artifact. Any player may
##         activate this ability but only during any upkeep step.
##
## Implementation: two triggers (upkeep tick, draw-step burn) plus a
## rewind ability that ANY player may activate (ActivatedAbility can be
## marked opponent-activated; here BOTH sides need it, so the card ships
## two copies of the ability — index 0 for the controller and index 1 for
## the opponents).
##
## The burn rides MtgGame's DRAW_STEP event, which is dispatched AFTER the
## turn-based draw — which is exactly right, not a shortcut: the active
## player draws first as a turn-based action (CR 504.1), and abilities that
## trigger at the beginning of the step only go on the stack the next time
## a player would receive priority (CR 117.5), i.e. after that draw. No
## player can act in between, so the two orders are indistinguishable.


func build() -> CardData:
	return CardData.new("Armageddon Clock", "{6}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _tick,
			"At the beginning of your upkeep, put a doom counter on Armageddon Clock.",
			_own_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DRAW_STEP, _burn,
			"At the beginning of your draw step, Armageddon Clock deals damage equal "
			+ "to the number of doom counters on it to each player.",
			_own_draw)) \
		.activated(ActivatedAbility.new(
			"{4}", false, [RemoveDoomEffect.new()],
			"{4}: Remove a doom counter from Armageddon Clock. Only during any upkeep step.") \
			.during_step(Mtg.Step.UPKEEP)) \
		.activated(ActivatedAbility.new(
			"{4}", false, [RemoveDoomEffect.new()],
			"{4}: Remove a doom counter (opponent's copy of the ability).") \
			.during_step(Mtg.Step.UPKEEP).opponent_activated()) \
		.oracle("At the beginning of your upkeep, put a doom counter on this "
			+ "artifact.\nAt the beginning of your draw step, this artifact deals "
			+ "damage equal to the number of doom counters on it to each player.\n"
			+ "{4}: Remove a doom counter from this artifact. Any player may activate "
			+ "this ability but only during any upkeep step.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _own_draw(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _tick(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "doom", 1)


static func _burn(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var n := int(source.counters.get("doom", 0))
	if n <= 0:
		return
	for p in game.players:
		if not p.has_lost:
			game.deal_damage(source, TargetRef.player(p.id), n)


class RemoveDoomEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var left := int(source.counters.get("doom", 0)) - 1
		if left <= 0:
			source.counters.erase("doom")
		else:
			source.counters["doom"] = left
		game.log_line("A doom counter is removed from Armageddon Clock")

	func describe() -> String:
		return "removes a doom counter"
