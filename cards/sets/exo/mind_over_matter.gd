extends CardScript
## Mind Over Matter — {2}{U}{U}{U}{U} — Enchantment (rare, exo).
## Oracle: Discard a card: You may tap or untap target artifact, creature, or land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Over Matter", "{2}{U}{U}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Discard a card: You may tap or untap target artifact, creature, or land.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
