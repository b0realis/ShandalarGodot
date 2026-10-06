extends CardScript
## Havoc — {1}{R} — Enchantment (uncommon, tmp).
## Oracle: Whenever an opponent casts a white spell, they lose 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Havoc", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a white spell, they lose 2 life.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
