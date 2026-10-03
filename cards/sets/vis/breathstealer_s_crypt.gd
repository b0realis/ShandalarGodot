extends CardScript
## Breathstealer's Crypt — {2}{U}{B} — Enchantment (rare, vis).
## Oracle: If a player would draw a card, instead they draw a card and reveal it. If it's a creature card, that player discards it unless they pay 3 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Breathstealer's Crypt", "{2}{U}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("If a player would draw a card, instead they draw a card and reveal it. If it's a creature card, that player discards it unless they pay 3 life.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
