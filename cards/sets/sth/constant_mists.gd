extends CardScript
## Constant Mists — {1}{G} — Instant (uncommon, sth).
## Oracle: Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Prevent all combat damage that would be dealt this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Constant Mists", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nPrevent all combat damage that would be dealt this turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
