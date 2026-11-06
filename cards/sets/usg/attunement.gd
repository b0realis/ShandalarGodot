extends CardScript
## Attunement — {2}{U} — Enchantment (rare, usg).
## Oracle: Return this enchantment to its owner's hand: Draw three cards, then discard four cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Attunement", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Return this enchantment to its owner's hand: Draw three cards, then discard four cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
