extends CardScript
## Coral Helm — {3} — Artifact — (4ed, rare)
## Oracle: {3}, Discard a card at random: Target creature gets +2/+2 until
##         end of turn.
##
## Implementation: an ActivatedAbility with the new random-discard cost
## (ActivatedAbility.with_random_discard_cost) and a PumpEffect payload.
## Repeatable as long as your hand holds out — the era's way of turning
## flooded hands into damage.


func build() -> CardData:
	return CardData.new("Coral Helm", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", false, [PumpEffect.new(2, 2)],
			"{3}, Discard a card at random: Target creature gets +2/+2 until end of turn.") \
			.with_random_discard_cost(1)) \
		.oracle("{3}, Discard a card at random: Target creature gets +2/+2 until end of turn.")
