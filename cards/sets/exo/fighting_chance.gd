extends CardScript
## Fighting Chance — {R} — Instant (rare, exo).
## Oracle: For each blocking creature, flip a coin. If you win the flip, prevent all combat damage that would be dealt by that creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fighting Chance", "{R}", Mtg.CardType.INSTANT)
	c.oracle("For each blocking creature, flip a coin. If you win the flip, prevent all combat damage that would be dealt by that creature this turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
