extends CardScript
## Tainted Aether — {2}{B}{B} — Enchantment (rare, usg).
## Oracle: Whenever a creature enters, its controller sacrifices a creature or land of their choice.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tainted Aether", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature enters, its controller sacrifices a creature or land of their choice.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
