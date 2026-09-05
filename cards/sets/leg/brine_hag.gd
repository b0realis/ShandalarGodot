extends CardScript
## Brine Hag — {2}{U}{U} — Creature — Hag — 2/2 — (leg, uncommon)
## Oracle: When this creature dies, change the base power and toughness of
##         all creatures that dealt damage to it this turn to 0/2.
##
## Implementation: a DIES trigger reading the damaged_by snapshot the
## engine carries in the event (per-instance damage sources are wiped by
## the battlefield-state reset, which is why the event carries them) and
## setting each survivor's base P/T with a floating 0/2 set.
##
## The curse lasts INDEFINITELY, exactly as the reminder text says — the
## base-P/T set is registered with ContinuousEffects.Duration.INDEFINITE,
## so it survives cleanup and every later turn. Only the cursed creature
## leaving the battlefield ends it (CR 400.7): what comes back is a new
## object and was never bitten.


func build() -> CardData:
	return CardData.new("Brine Hag", "{2}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["hag"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _curse,
			"When Brine Hag dies, change the base power and toughness of all "
			+ "creatures that dealt damage to it this turn to 0/2.",
			_is_self)) \
		.oracle("When this creature dies, change the base power and toughness of all "
			+ "creatures that dealt damage to it this turn to 0/2. (This effect lasts "
			+ "indefinitely.)")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _curse(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	for id in event.data.get("damaged_by", []):
		var killer := game.find_instance(int(id))
		if killer != null and killer.zone == Mtg.Zone.BATTLEFIELD and killer.is_creature():
			game.continuous.add_until_eot_base_pt(killer.id, 0, 2, false,
				ContinuousEffects.Duration.INDEFINITE)
	game.recalculate()
