extends CardScript
## Shard Phoenix — {4}{R} — Creature — Phoenix (rare, sth).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         Sacrifice this creature: It deals 2 damage to each creature without flying.
##         {R}{R}{R}: Return this card from your graveyard to your hand. Activate only during your upkeep.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shard Phoenix", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phoenix"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\nSacrifice this creature: It deals 2 damage to each creature without flying.\n{R}{R}{R}: Return this card from your graveyard to your hand. Activate only during your upkeep.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
