extends CardScript
## Reaping the Rewards — {W} — Instant (common, exo).
## Oracle: Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         You gain 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reaping the Rewards", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nYou gain 2 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
