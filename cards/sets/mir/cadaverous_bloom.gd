extends CardScript
## Cadaverous Bloom — {3}{B}{G} — Enchantment (rare, mir).
## Oracle: Exile a card from your hand: Add {B}{B} or {G}{G}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cadaverous Bloom", "{3}{B}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Exile a card from your hand: Add {B}{B} or {G}{G}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
