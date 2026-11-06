extends CardScript
## Veiled Serpent — {2}{U} — Enchantment (common, usg).
## Oracle: When an opponent casts a spell, if this permanent is an enchantment, it becomes a 4/4 Serpent creature with "This creature can't attack unless defending player controls an Island."
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Veiled Serpent", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a spell, if this permanent is an enchantment, it becomes a 4/4 Serpent creature with \"This creature can't attack unless defending player controls an Island.\"\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
