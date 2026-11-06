extends CardScript
## Sneak Attack — {3}{R} — Enchantment (rare, usg).
## Oracle: {R}: You may put a creature card from your hand onto the battlefield. That creature gains haste. Sacrifice the creature at the beginning of the next end step.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sneak Attack", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{R}: You may put a creature card from your hand onto the battlefield. That creature gains haste. Sacrifice the creature at the beginning of the next end step.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
