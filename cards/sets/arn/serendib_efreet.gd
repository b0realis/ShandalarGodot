extends CardScript
## Serendib Efreet — {2}{U} — Creature — Efreet — 3/4 — (arn, rare)
## Oracle: Flying
##         At the beginning of your upkeep, this creature deals 1 damage
##         to you.
##
## Implementation: Juzám's blue cousin (juzam_djinn.gd) — a 3/4 flyer for
## three with the same one-a-turn bite.


func build() -> CardData:
	return CardData.new("Serendib Efreet", "{2}{U}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_subtypes(["efreet"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _bite,
			"At the beginning of your upkeep, this creature deals 1 damage to you.",
			_own_upkeep)) \
		.oracle("Flying\nAt the beginning of your upkeep, this creature deals 1 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


## The bite resolves even if the creature left the battlefield in response
## (CR 603.6 / 608.2h — a triggered ability exists independently of its
## source): the damage comes from it as it last existed, to the player who
## controlled the trigger. It used to fizzle (until 2026-10-03).
static func _bite(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := game.current_resolution_controller()
	if pid < 0:
		pid = source.controller_id
	game.deal_damage(source, TargetRef.player(pid), 1)
