extends CardScript
## Contamination — {2}{B} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a creature.
##         If a land is tapped for mana, it produces {B} instead of any other type and amount.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Contamination", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a creature.\nIf a land is tapped for mana, it produces {B} instead of any other type and amount.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
