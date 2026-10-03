extends CardScript
## Teferi's Realm — {1}{U}{U} — World Enchantment (rare, vis).
## Oracle: At the beginning of each player's upkeep, that player chooses artifact, creature, land, or non-Aura enchantment. All nontoken permanents of that type phase out. (While they're phased out, they're treated as though they don't exist. Each one phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Realm", "{1}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("At the beginning of each player's upkeep, that player chooses artifact, creature, land, or non-Aura enchantment. All nontoken permanents of that type phase out. (While they're phased out, they're treated as though they don't exist. Each one phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
