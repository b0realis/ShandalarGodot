extends CardScript
## Prismatic Dragon — {2}{W}{W} — Creature — Dragon — 2/3 — (past, common)
## Oracle: Flying
##         During your upkeep, Prismatic Dragon becomes a random color
##         permanently.
##         {2}: Prismatic Dragon becomes a random color permanently.
##
## Implementation: two routes into the same repaint — an upkeep trigger and
## a {2} ability — both rolling through RandomEffects.color (game.rng, so a
## seeded duel replays the Dragon's wardrobe exactly). "Permanently" is the
## indefinite colour change from wave 44.


func build() -> CardData:
	return CardData.new("Prismatic Dragon", "{2}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _repaint_trigger,
			"During your upkeep, Prismatic Dragon becomes a random color permanently.",
			_your_upkeep)) \
		.activated(ActivatedAbility.new("{2}", false, [RepaintSelfEffect.new()],
			"{2}: Prismatic Dragon becomes a random color permanently.")) \
		.oracle("Flying\nDuring your upkeep, Prismatic Dragon becomes a random color permanently.\n{2}: Prismatic Dragon becomes a random color permanently.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _repaint_trigger(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.set_color(source, RandomEffects.color(game))


class RepaintSelfEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.set_color(source, RandomEffects.color(game))

	func describe() -> String:
		return "becomes a random color permanently"
