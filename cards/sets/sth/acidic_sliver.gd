extends CardScript
## Acidic Sliver — {B}{R} — Creature — Sliver (uncommon, sth).
## Oracle: All Slivers have "{2}, Sacrifice this permanent: This permanent deals 2 damage to any target."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Acidic Sliver", "{B}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have \"{2}, Sacrifice this permanent: This permanent deals 2 damage to any target.\"")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
