extends CardScript
## Stone Calendar — {5} — Artifact — (drk, rare)
## Oracle: Spells you cast cost {1} less to cast.
##
## Implementation: a flat negative cost modifier on everything its
## controller casts. Because reductions are clamped at the printed
## generic part, a one-coloured-pip spell like Lightning Bolt still costs
## its {R} — which the test pins.


func build() -> CardData:
	return CardData.new("Stone Calendar", "{5}", Mtg.CardType.ARTIFACT) \
		.with_cost_modifier(_discount) \
		.oracle("Spells you cast cost {1} less to cast.")


## Asked about its OWN source, so "spells you cast" is this Calendar's
## controller — an opposing Calendar no longer discounts your spells.
static func _discount(_game: MtgGame, caster: int, _data: CardData,
		source: CardInstance) -> int:
	return -1 if source.controller_id == caster else 0
