extends CardScript
## Shauku's Minion — {1}{B}{R} — Creature — Human Minion (uncommon, mir).
## Oracle: {B}{R}, {T}: This creature deals 2 damage to target white creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shauku's Minion", "{1}{B}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","minion"])
	c.oracle("{B}{R}, {T}: This creature deals 2 damage to target white creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
