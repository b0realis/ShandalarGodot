extends CardScript
## Goblin Cadets — {R} — Creature — Goblin (uncommon, usg).
## Oracle: Whenever this creature blocks or becomes blocked, target opponent gains control of it. (This removes this creature from combat.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Cadets", "{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Whenever this creature blocks or becomes blocked, target opponent gains control of it. (This removes this creature from combat.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
