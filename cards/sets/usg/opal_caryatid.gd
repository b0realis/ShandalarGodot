extends CardScript
## Opal Caryatid — {W} — Enchantment (common, usg).
## Oracle: When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/2 Soldier creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opal Caryatid", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/2 Soldier creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
