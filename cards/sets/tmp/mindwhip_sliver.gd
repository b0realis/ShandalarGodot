extends CardScript
## Mindwhip Sliver — {2}{B} — Creature — Sliver (uncommon, tmp).
## Oracle: All Slivers have "{2}, Sacrifice this permanent: Target player discards a card at random. Activate only as a sorcery."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mindwhip Sliver", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"{2}, Sacrifice this permanent: Target player discards a card at random. Activate only as a sorcery.\"")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
