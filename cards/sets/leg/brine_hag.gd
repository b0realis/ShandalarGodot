extends CardScript
## Brine Hag — {2}{U}{U} — Creature — Hag — 2/2 — (leg, uncommon)
## Oracle: When this creature dies, change the base power and toughness of
##         all creatures that dealt damage to it this turn to 0/2.
##
## Implementation: a DIES trigger reading the damage_origins snapshot the
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


## Each damage source is keyed "id:timestamp" in the event's
## `damage_origins` (the bug campaign c12, h3-14): a creature that bit the
## Hag and has since left the battlefield and come back is a new object
## (CR 400.7) and is spared — by id alone it was cursed.
static func _curse(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	for key in event.data.get("damage_origins", {}):
		var parts := String(key).split(":")
		if parts.size() != 2:
			continue
		var killer := game.find_instance(int(parts[0]))
		# A phased-out killer isn't included, not even once back (CR 702.26e).
		if game.is_present(killer) and killer.is_creature() \
				and killer.layer_timestamp == int(parts[1]):
			game.continuous.add_until_eot_base_pt(killer.id, 0, 2, false,
				ContinuousEffects.Duration.INDEFINITE)
	game.recalculate()
