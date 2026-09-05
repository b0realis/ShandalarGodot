extends CardScript
## Karma — {2}{W}{W} — Enchantment (2ed, uncommon)
## Oracle: At the beginning of each player's upkeep, Karma deals damage to
##         that player equal to the number of Swamps they control.
##
## Implementation: UPKEEP_START trigger, damage computed live from the
## event player's swamp count (subtypes — Bayou counts). Symmetric as
## printed: run it alongside your own duals at your peril. The Paladin
## deck's anti-black hammer per the dos486 enemy notes.


func build() -> CardData:
	return CardData.new("Karma", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START,
			_burn_for_swamps,
			"At the beginning of each player's upkeep, Karma deals damage to that player equal to the number of Swamps they control.")) \
		.oracle("At the beginning of each player's upkeep, Karma deals damage to that player equal to the number of Swamps they control.")


static func _burn_for_swamps(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["player"]
	var swamps := 0
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.has_subtype("swamp"):
			swamps += 1
	if swamps > 0:
		game.deal_damage(source, TargetRef.player(pid), swamps)
