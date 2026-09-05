extends CardScript
## Mox Jet — {0} — Artifact (2ed, rare; Power Nine)
## Oracle: {T}: Add {B}.
##
## Implementation: a zero-cost mana artifact — one black ManaAbility.
## Like Sol Ring, it has no summoning sickness (CR 302.6 is creature-only)
## so it taps the turn it arrives. Restricted in Shandalar's deck rules.
## One of five: see the other mox_*.gd files.


func build() -> CardData:
	return CardData.new("Mox Jet", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.oracle("{T}: Add {B}.")
