extends CardScript
## False Summoning — {1}{U} — Instant (Portal Second Age, 1998).
## Oracle: Counter target creature spell.

func build() -> CardData:
	var c := CardData.new("False Summoning", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target creature spell.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
