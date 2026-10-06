extends CardScript
## Flowstone Salamander — {3}{R}{R} — Creature — Salamander (uncommon, tmp).
## Oracle: {R}: This creature deals 1 damage to target creature blocking it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Salamander", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["salamander"])
	c.oracle("{R}: This creature deals 1 damage to target creature blocking it.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
