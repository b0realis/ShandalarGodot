extends CardScript
## Tormod's Crypt — {0} — Artifact — (drk, uncommon)
## Oracle: {T}, Sacrifice this artifact: Exile target player's graveyard.
##
## Implementation: a free artifact whose activation sacrifices itself
## (ActivatedAbility.with_sacrifice_cost) and exiles every card in the
## target player's graveyard. Zero mana in, zero mana out — the answer to
## Animate Dead, Raise Dead and every other graveyard engine in the pool.


func build() -> CardData:
	return CardData.new("Tormod's Crypt", "{0}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [CryptEffect.new()],
			"{T}, Sacrifice Tormod's Crypt: Exile target player's graveyard.") \
			.with_sacrifice_cost()) \
		.oracle("{T}, Sacrifice this artifact: Exile target player's graveyard.")


class CryptEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var doomed := game.players[target.player_id].graveyard.duplicate()
		for inst in doomed:
			game.exile_from_graveyard(inst)

	func describe() -> String:
		return "exiles target player's graveyard"
