extends CardScript
## Goblin Grenadiers — {3}{R} — Creature — Goblin (uncommon, wth).
## Oracle: Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, destroy target creature and target land.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Grenadiers", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, destroy target creature and target land.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
