extends CardScript
## Squandered Resources — {B}{G} — Enchantment (rare, vis).
## Oracle: Sacrifice a land: Add one mana of any type the sacrificed land could produce.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Squandered Resources", "{B}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a land: Add one mana of any type the sacrificed land could produce.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
