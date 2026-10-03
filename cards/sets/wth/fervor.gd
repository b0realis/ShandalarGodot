extends CardScript
## Fervor — {2}{R} — Enchantment (rare, wth).
## Oracle: Creatures you control have haste. (They can attack and {T} as soon as they come under your control.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fervor", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have haste. (They can attack and {T} as soon as they come under your control.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
