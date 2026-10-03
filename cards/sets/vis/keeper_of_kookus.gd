extends CardScript
## Keeper of Kookus — {R} — Creature — Goblin (common, vis).
## Oracle: {R}: This creature gains protection from red until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of Kookus", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("{R}: This creature gains protection from red until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
