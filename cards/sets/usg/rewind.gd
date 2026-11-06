extends CardScript
## Rewind — {2}{U}{U} — Instant (common, usg).
## Oracle: Counter target spell. Untap up to four lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rewind", "{2}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell. Untap up to four lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
