extends CardScript
## Vebulid — {B} — Creature — Phyrexian Horror (rare, usg).
## Oracle: This creature enters with a +1/+1 counter on it.
##         At the beginning of your upkeep, you may put a +1/+1 counter on this creature.
##         When this creature attacks or blocks, destroy it at end of combat.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vebulid", "{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["phyrexian","horror"])
	c.oracle("This creature enters with a +1/+1 counter on it.\nAt the beginning of your upkeep, you may put a +1/+1 counter on this creature.\nWhen this creature attacks or blocks, destroy it at end of combat.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
