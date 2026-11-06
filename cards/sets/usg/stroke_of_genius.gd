extends CardScript
## Stroke of Genius — {X}{2}{U} — Instant (rare, usg).
## Oracle: Target player draws X cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stroke of Genius", "{X}{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Target player draws X cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
