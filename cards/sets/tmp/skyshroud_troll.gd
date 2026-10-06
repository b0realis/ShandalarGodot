extends CardScript
## Skyshroud Troll — {2}{G}{G} — Creature — Troll Giant (common, tmp).
## Oracle: {1}{G}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Troll", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["troll","giant"])
	c.oracle("{1}{G}: Regenerate this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
