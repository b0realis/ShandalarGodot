extends CardScript
## Mox Emerald — {0} — Artifact (2ed, rare; Power Nine)
## Oracle: {T}: Add {G}.
##
## Implementation: a zero-cost mana artifact — one green ManaAbility.
## Like Sol Ring, it has no summoning sickness (CR 302.6 is creature-only)
## so it taps the turn it arrives. Restricted in Shandalar's deck rules.
## One of five: see the other mox_*.gd files.


func build() -> CardData:
	return CardData.new("Mox Emerald", "{0}", Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("{T}: Add {G}.")
