extends CardScript
## Warrior Angel — {4}{W}{W} — Creature — Angel Warrior (rare, sth).
## Oracle: Flying
##         Whenever this creature deals damage, you gain that much life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Warrior Angel", "{4}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["angel","warrior"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature deals damage, you gain that much life.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
