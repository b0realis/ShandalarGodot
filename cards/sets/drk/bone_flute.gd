extends CardScript
## Bone Flute — {3} — Artifact — (drk, uncommon)
## Oracle: {2}, {T}: All creatures get -1/-0 until end of turn.
##
## Implementation: Marsh Gas on an activation (MassPumpEffect) — every
## creature, both sides, loses a point of power for the turn.


func build() -> CardData:
	return CardData.new("Bone Flute", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[MassPumpEffect.new(-1, 0)],
			"{2}, {T}: All creatures get -1/-0 until end of turn.")) \
		.oracle("{2}, {T}: All creatures get -1/-0 until end of turn.")
