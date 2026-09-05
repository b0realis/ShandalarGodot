extends CardScript
## Spiritual Sanctuary — {2}{W}{W} — Enchantment — (leg, rare)
## Oracle: At the beginning of each player's upkeep, if that player
##         controls a Plains, they gain 1 life.
##
## Implementation: an UPKEEP_START trigger with an intervening "if" —
## re-checked at resolution as well as on triggering (CR 603.4), which is
## the Land Tax lesson from the audit. Symmetric: an opponent on Plains
## gains too.


func build() -> CardData:
	return CardData.new("Spiritual Sanctuary", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _gain,
			"At the beginning of each player's upkeep, if that player controls a "
			+ "Plains, they gain 1 life.",
			_controls_a_plains)) \
		.oracle("At the beginning of each player's upkeep, if that player controls a "
			+ "Plains, they gain 1 life.")


static func _has_plains(game: MtgGame, pid: int) -> bool:
	for inst in game.all_battlefield():
		if inst.controller_id == pid and inst.is_land() and inst.has_subtype("plains"):
			return true
	return false


static func _controls_a_plains(game: MtgGame, _source: CardInstance,
		event: GameEvent) -> bool:
	return _has_plains(game, int(event.data["player"]))


static func _gain(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	if _has_plains(game, pid):   # intervening "if" re-checked (CR 603.4)
		game.adjust_life(pid, 1)
