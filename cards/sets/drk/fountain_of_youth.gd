extends CardScript
## Fountain of Youth — {0} — Artifact (drk, uncommon)
## Oracle: {2}, {T}: You gain 1 life.
##
## Implementation: trivial mana+tap life trickle — and the first card in
## the drk set folder (Duels of the Planeswalkers expansion material
## starts graduating here).


func build() -> CardData:
	return CardData.new("Fountain of Youth", "{0}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[GainLifeEffect.new(1)],
			"{2}, {T}: You gain 1 life.")) \
		.oracle("{2}, {T}: You gain 1 life.")
