extends CardScript
## Forbid — {1}{U}{U} — Instant (uncommon, exo).
## Oracle: Buyback—Discard two cards. (You may discard two cards in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Counter target spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Forbid", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Buyback—Discard two cards. (You may discard two cards in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nCounter target spell.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
