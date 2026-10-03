extends CardScript
## Viashino Warrior — {3}{R} — Creature — Lizard Warrior (common, mir).
## Oracle: (No rules text.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Warrior", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 2)
	c.with_subtypes(["lizard","warrior"])
	c.oracle("")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
