extends CardScript
## Warmth — {1}{W} — Enchantment (uncommon, tmp).
## Oracle: Whenever an opponent casts a red spell, you gain 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Warmth", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a red spell, you gain 2 life.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
