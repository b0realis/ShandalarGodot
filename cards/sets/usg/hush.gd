extends CardScript
## Hush — {3}{G} — Sorcery (common, usg).
## Oracle: Destroy all enchantments.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hush", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all enchantments.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
