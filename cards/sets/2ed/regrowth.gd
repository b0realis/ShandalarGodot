extends CardScript
## Regrowth — {1}{G} — Sorcery (2ed, uncommon)
## Oracle: Return target card from your graveyard to your hand.
##
## Implementation: ReturnFromGraveyardEffect.any_card() — ANY card type,
## via the CARD_IN_YOUR_GRAVEYARD target kind. With this card the
## Timetwister–Regrowth loop from the dos486 guide's Arzakon kill is fully
## playable in the engine. Restricted in the era's rules, for exactly that
## reason.


func build() -> CardData:
	return CardData.new("Regrowth", "{1}{G}", Mtg.CardType.SORCERY) \
		.spell(ReturnFromGraveyardEffect.new().any_card()) \
		.oracle("Return target card from your graveyard to your hand.")
