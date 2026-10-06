extends CardScript
## Kor Chant — {2}{W} — Instant (common, exo).
## Oracle: All damage that would be dealt this turn to target creature you control by a source of your choice is dealt to another target creature instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kor Chant", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("All damage that would be dealt this turn to target creature you control by a source of your choice is dealt to another target creature instead.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
