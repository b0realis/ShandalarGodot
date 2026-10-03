extends CardScript
## Rowen — {2}{G}{G} — Enchantment (rare, vis).
## Oracle: Reveal the first card you draw each turn. Whenever you reveal a basic land card this way, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rowen", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Reveal the first card you draw each turn. Whenever you reveal a basic land card this way, draw a card.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
