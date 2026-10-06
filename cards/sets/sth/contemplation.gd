extends CardScript
## Contemplation — {1}{W}{W} — Enchantment (uncommon, sth).
## Oracle: Whenever you cast a spell, you gain 1 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Contemplation", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever you cast a spell, you gain 1 life.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
