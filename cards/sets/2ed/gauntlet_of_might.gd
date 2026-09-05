extends CardScript
## Gauntlet of Might — {4} — Artifact — (2ed, rare)
## Oracle: Red creatures get +1/+1.
##         Whenever a Mountain is tapped for mana, its controller adds an
##         additional {R}.
##
## Implementation: a global anthem for red plus a TAPPED_FOR_MANA trigger
## marked as a MANA trigger (CR 605.1b — it resolves off-stack, so the
## extra red is in the pool while the payment that tapped the Mountain is
## still being made). Symmetric, but only a red deck ever plays it.


func build() -> CardData:
	return CardData.new("Gauntlet of Might", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_apply, "Red creatures get +1/+1.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.TAPPED_FOR_MANA, _double,
			"Whenever a Mountain is tapped for mana, its controller adds an additional {R}.",
			_is_mountain).as_mana_trigger()) \
		.oracle("Red creatures get +1/+1.\nWhenever a Mountain is tapped for mana, "
			+ "its controller adds an additional {R}.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.R) != 0:
			inst.cur_power += 1
			inst.cur_toughness += 1


static func _is_mountain(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.is_land() and inst.has_subtype("mountain")


static func _double(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.players[int(event.data["controller"])].mana_pool.add(Mtg.ManaColor.R, 1)
