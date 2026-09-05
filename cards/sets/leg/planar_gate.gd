extends CardScript
## Planar Gate — {6} — Artifact — (leg, rare)
## Oracle: Creature spells you cast cost {2} less to cast.
##
## Implementation: Mana Matrix's negative cost modifier aimed at creature
## spells. Six mana up front for two mana a creature afterwards — the
## Legends way of building a ramp deck.


func build() -> CardData:
	return CardData.new("Planar Gate", "{6}", Mtg.CardType.ARTIFACT) \
		.with_cost_modifier(_discount) \
		.oracle("Creature spells you cast cost {2} less to cast.")


## Asked about its OWN source, so "spells you cast" is this Gate's
## controller — an opposing Gate no longer discounts your creatures.
static func _discount(_game: MtgGame, caster: int, data: CardData,
		source: CardInstance) -> int:
	if source.controller_id != caster:
		return 0
	return -2 if data.is_type(Mtg.CardType.CREATURE) else 0
