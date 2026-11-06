extends CardScript
## Humble — {1}{W} — Instant (uncommon, usg).
## Oracle: Until end of turn, target creature loses all abilities and has base power and toughness 0/1.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Humble", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Until end of turn, target creature loses all abilities and has base power and toughness 0/1.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
