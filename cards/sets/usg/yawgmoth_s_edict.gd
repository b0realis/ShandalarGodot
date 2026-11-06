extends CardScript
## Yawgmoth's Edict — {1}{B} — Enchantment (uncommon, usg).
## Oracle: Whenever an opponent casts a white spell, that player loses 1 life and you gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yawgmoth's Edict", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a white spell, that player loses 1 life and you gain 1 life.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
