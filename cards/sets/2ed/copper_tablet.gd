extends CardScript
## Copper Tablet — {2} — Artifact (2ed, uncommon)
## Oracle: At the beginning of each player's upkeep, Copper Tablet deals 1
##         damage to that player.
##
## Implementation: the symmetric upkeep-burn artifact (Karma's pattern,
## colorless and unconditional). A clock on the whole table.


func build() -> CardData:
	return CardData.new("Copper Tablet", "{2}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _tick,
			"At the beginning of each player's upkeep, Copper Tablet deals 1 damage to that player.")) \
		.oracle("At the beginning of each player's upkeep, Copper Tablet deals 1 damage to that player.")


static func _tick(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
