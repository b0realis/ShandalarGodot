extends CardScript
## Sleeper Agent — {B} — Creature — Phyrexian Minion (rare, usg).
## Oracle: When this creature enters, target opponent gains control of it.
##         At the beginning of your upkeep, this creature deals 2 damage to you.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sleeper Agent", "{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","minion"])
	c.oracle("When this creature enters, target opponent gains control of it.\nAt the beginning of your upkeep, this creature deals 2 damage to you.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
