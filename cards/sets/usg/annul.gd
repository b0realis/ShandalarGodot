extends CardScript
## Annul — {U} — Instant (common, usg).
## Oracle: Counter target artifact or enchantment spell.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Annul", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target artifact or enchantment spell.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
