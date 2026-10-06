extends CardScript
## Dream Halls — {3}{U}{U} — Enchantment (rare, sth).
## Oracle: Rather than pay the mana cost for a spell, its controller may discard a card that shares a color with that spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dream Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Rather than pay the mana cost for a spell, its controller may discard a card that shares a color with that spell.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
