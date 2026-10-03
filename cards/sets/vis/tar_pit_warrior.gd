extends CardScript
## Tar Pit Warrior — {2}{B} — Creature — Cyclops Warrior (common, vis).
## Oracle: When this creature becomes the target of a spell or ability, sacrifice it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tar Pit Warrior", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["cyclops","warrior"])
	c.oracle("When this creature becomes the target of a spell or ability, sacrifice it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
