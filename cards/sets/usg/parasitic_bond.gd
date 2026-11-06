extends CardScript
## Parasitic Bond — {3}{B} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         At the beginning of the upkeep of enchanted creature's controller, this Aura deals 2 damage to that player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Parasitic Bond", "{3}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of the upkeep of enchanted creature's controller, this Aura deals 2 damage to that player.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
