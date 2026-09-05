extends CardScript
## Boomerang — {U}{U} — Instant — (leg, common)
## Oracle: Return target permanent to its owner's hand.
##
## Implementation: ReturnToHandEffect with an unfiltered PERMANENT spec —
## Unsummon that hits anything, including lands. The tempo staple that
## made Legends draft's blue decks tick.


func build() -> CardData:
	return CardData.new("Boomerang", "{U}{U}", Mtg.CardType.INSTANT) \
		.spell(ReturnToHandEffect.new(
			TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))) \
		.oracle("Return target permanent to its owner's hand.")
