extends CardScript
## Blessed Reversal — {1}{W} — Instant (Portal, 1997).
## Oracle: You gain 3 life for each creature attacking you.

func build() -> CardData:
	var c := CardData.new("Blessed Reversal", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("You gain 3 life for each creature attacking you.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
