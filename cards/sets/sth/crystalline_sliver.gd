extends CardScript
## Crystalline Sliver — {W}{U} — Creature — Sliver (uncommon, sth).
## Oracle: All Slivers have shroud. (They can't be the targets of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crystalline Sliver", "{W}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Slivers have shroud. (They can't be the targets of spells or abilities.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
