extends CardScript
## Chaosphere — {2}{R} — World Enchantment (rare, mir).
## Oracle: Creatures with flying can block only creatures with flying.
##         Creatures without flying have reach. (They can block creatures with flying.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chaosphere", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("Creatures with flying can block only creatures with flying.\nCreatures without flying have reach. (They can block creatures with flying.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
