extends CardScript
## Hidden Predators — {G} — Enchantment (rare, usg).
## Oracle: When an opponent controls a creature with power 4 or greater, if this permanent is an enchantment, it becomes a 4/4 Beast creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Predators", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent controls a creature with power 4 or greater, if this permanent is an enchantment, it becomes a 4/4 Beast creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
