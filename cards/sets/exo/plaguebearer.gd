extends CardScript
## Plaguebearer — {1}{B} — Creature — Zombie (rare, exo).
## Oracle: {X}{X}{B}: Destroy target nonblack creature with mana value X.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plaguebearer", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["zombie"])
	c.oracle("{X}{X}{B}: Destroy target nonblack creature with mana value X.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
