extends CardScript
## Eye of Singularity — {3}{W} — World Enchantment (rare, vis).
## Oracle: When this enchantment enters, destroy each permanent with the same name as another permanent, except for basic lands. They can't be regenerated.
##         Whenever a permanent other than a basic land enters, destroy all other permanents with that name. They can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eye of Singularity", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("When this enchantment enters, destroy each permanent with the same name as another permanent, except for basic lands. They can't be regenerated.\nWhenever a permanent other than a basic land enters, destroy all other permanents with that name. They can't be regenerated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
