extends CardScript
## Millstone — {2} — Artifact (4ed, rare; first printed in Antiquities)
## Oracle: {2}, {T}: Target player mills two cards.
##
## Implementation: mana+tap activated ability with MillEffect(2) — the card
## that named the mechanic. Milling out is not itself a loss; the kill
## arrives when the victim must DRAW from the empty library (CR 120.3),
## which the engine already enforces.


func build() -> CardData:
	return CardData.new("Millstone", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[MillEffect.new(2)],
			"{2}, {T}: Target player mills two cards.")) \
		.oracle("{2}, {T}: Target player mills two cards.")
