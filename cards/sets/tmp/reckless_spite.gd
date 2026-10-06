extends CardScript
## Reckless Spite — {1}{B}{B} — Instant (uncommon, tmp).
## Oracle: Destroy two target nonblack creatures. You lose 5 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reckless Spite", "{1}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Destroy two target nonblack creatures. You lose 5 life.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
