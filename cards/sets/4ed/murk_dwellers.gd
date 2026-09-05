extends CardScript
## Murk Dwellers — {3}{B} — Creature — Zombie — 2/2 — (4ed, common)
## Oracle: Whenever this creature attacks and isn't blocked, it gets
##         +2/+0 until end of combat.
##
## Implementation: a BLOCKERS_DECLARED trigger — once all blocks are in,
## if it attacked and drew no blocker, a +2/+0 floating pump with the
## until-end-of-combat expiry lands on it.


func build() -> CardData:
	return CardData.new("Murk Dwellers", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["zombie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKERS_DECLARED, _emerge,
			"Whenever this creature attacks and isn't blocked, it gets +2/+0 until end of combat.",
			_attacking_unblocked)) \
		.oracle("Whenever this creature attacks and isn't blocked, it gets +2/+0 until end of combat.")


static func _attacking_unblocked(game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return game.combat.attackers.has(source.id) \
		and game.combat.blockers_of_band(game.combat.band_of(source.id)).is_empty()


static func _emerge(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.continuous.add_until_eot_pump(source.id, 2, 0, [], true)
	game.log_line("%s gets +2/+0 until end of combat" % source.data.card_name)
	game.recalculate()
