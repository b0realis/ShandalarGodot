extends CardScript
## Pillar Tombs of Aku — {2}{B}{B} — World Enchantment (rare, vis).
## Oracle: At the beginning of each player's upkeep, that player may sacrifice a creature of their choice. If that player doesn't, they lose 5 life and you sacrifice this enchantment.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pillar Tombs of Aku", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.supertypes |= Mtg.Supertype.WORLD
	c.oracle("At the beginning of each player's upkeep, that player may sacrifice a creature of their choice. If that player doesn't, they lose 5 life and you sacrifice this enchantment.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
