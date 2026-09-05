extends CardScript
## Book of Rass — {6} — Artifact — Book — (drk, uncommon)
## Oracle: {2}, Pay 2 life: Draw a card.
##
## Implementation: mana + life cost (with_life_cost) feeding a DrawEffect
## — the classic life-to-cards engine, no tap so it can chain.


func build() -> CardData:
	return CardData.new("Book of Rass", "{6}", Mtg.CardType.ARTIFACT) \
		.with_subtypes(["book"]) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[DrawEffect.new(1)],
			"{2}, Pay 2 life: Draw a card.").with_life_cost(2)) \
		.oracle("{2}, Pay 2 life: Draw a card.")
