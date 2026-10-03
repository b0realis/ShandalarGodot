extends CardScript
## Final Fortune — {R}{R} — Instant (rare, mir).
## Oracle: Take an extra turn after this one. At the beginning of that turn's end step, you lose the game.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Final Fortune", "{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Take an extra turn after this one. At the beginning of that turn's end step, you lose the game.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
