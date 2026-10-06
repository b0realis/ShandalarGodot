extends CardScript
## Whiptongue Frog — {2}{U} — Creature — Frog (common, exo).
## Oracle: {U}: This creature gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Whiptongue Frog", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["frog"])
	c.oracle("{U}: This creature gains flying until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
