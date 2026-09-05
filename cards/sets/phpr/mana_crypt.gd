extends CardScript
## Mana Crypt — {0} — Artifact — (phpr, rare)
## Oracle: At the beginning of your upkeep, flip a coin. If you lose the
##         flip, this artifact deals 3 damage to you.
##         {T}: Add {C}{C}.
##
## Implementation: free mana with a real cost. The flip goes through
## MtgGame.flip_coin — seeded, so a replayed duel loses the same flips.


func build() -> CardData:
	return CardData.new("Mana Crypt", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 2)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _the_toll,
			"At the beginning of your upkeep, flip a coin. If you lose the flip, this artifact deals 3 damage to you.",
			_your_upkeep)) \
		.oracle("At the beginning of your upkeep, flip a coin. If you lose the flip, this artifact deals 3 damage to you.\n{T}: Add {C}{C}.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _the_toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	if game.flip_coin(pid):
		return
	game.deal_damage(source, TargetRef.player(pid), 3)
