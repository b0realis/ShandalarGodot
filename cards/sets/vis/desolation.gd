extends CardScript
## Desolation — {1}{B}{B} — Enchantment (uncommon, vis).
## Oracle: At the beginning of each end step, each player who tapped a land for mana this turn sacrifices a land of their choice. This enchantment deals 2 damage to each player who sacrificed a Plains this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Desolation", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each end step, each player who tapped a land for mana this turn sacrifices a land of their choice. This enchantment deals 2 damage to each player who sacrificed a Plains this way.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
