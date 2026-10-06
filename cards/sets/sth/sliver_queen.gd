extends CardScript
## Sliver Queen — {W}{U}{B}{R}{G} — Legendary Creature — Sliver (rare, sth).
## Oracle: {2}: Create a 1/1 colorless Sliver creature token.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sliver Queen", "{W}{U}{B}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["sliver"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{2}: Create a 1/1 colorless Sliver creature token.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
