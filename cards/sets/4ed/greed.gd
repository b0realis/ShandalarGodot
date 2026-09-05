extends CardScript
## Greed — {3}{B} — Enchantment (4ed, rare; first printed in Legends)
## Oracle: {B}, Pay 2 life: Draw a card.
##
## Implementation: the reference LIFE-COST card — {B} plus 2 life buys a
## card, payable down to exactly 0 life (state-based actions then collect,
## CR 118.4). The Black castle's standing enchantment per the dos486
## guide: "the computer spends all its life drawing cards" — and now ours
## can make the same mistake on purpose at low difficulties.


func build() -> CardData:
	return CardData.new("Greed", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[DrawEffect.new(1)],
			"{B}, Pay 2 life: Draw a card.").with_life_cost(2)) \
		.oracle("{B}, Pay 2 life: Draw a card.")
