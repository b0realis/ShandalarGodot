extends CardScript
## Electryte — {3}{R}{R} — Creature — Trilobite Beast (rare, usg).
## Oracle: Whenever this creature deals combat damage to defending player, it deals damage equal to its power to each blocking creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Electryte", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["trilobite","beast"])
	c.oracle("Whenever this creature deals combat damage to defending player, it deals damage equal to its power to each blocking creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
