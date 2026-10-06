extends CardScript
## Hibernation Sliver — {U}{B} — Creature — Sliver (uncommon, sth).
## Oracle: All Slivers have "Pay 2 life: Return this permanent to its owner's hand."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hibernation Sliver", "{U}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"Pay 2 life: Return this permanent to its owner's hand.\"")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
