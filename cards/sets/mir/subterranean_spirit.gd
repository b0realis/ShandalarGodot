extends CardScript
## Subterranean Spirit — {3}{R}{R} — Creature — Elemental Spirit (rare, mir).
## Oracle: Protection from red
##         {T}: This creature deals 1 damage to each creature without flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Subterranean Spirit", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elemental","spirit"])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Protection from red\n{T}: This creature deals 1 damage to each creature without flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
