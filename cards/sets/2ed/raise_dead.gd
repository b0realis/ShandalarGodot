extends CardScript
## Raise Dead — {B} — Sorcery (2ed, common)
## Oracle: Return target creature card from your graveyard to your hand.
##
## Implementation: ReturnFromGraveyardEffect using the
## CREATURE_IN_YOUR_GRAVEYARD target kind (the first graveyard-reaching
## card in the pool — the target kind's "your" restriction is documented
## on the spec). Fizzles cleanly if the card leaves the graveyard in
## response.


func build() -> CardData:
	return CardData.new("Raise Dead", "{B}", Mtg.CardType.SORCERY) \
		.spell(ReturnFromGraveyardEffect.new()) \
		.oracle("Return target creature card from your graveyard to your hand.")
