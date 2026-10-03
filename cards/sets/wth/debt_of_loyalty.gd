extends CardScript
## Debt of Loyalty — {1}{W}{W} — Instant (rare, wth).
## Oracle: Regenerate target creature. You gain control of that creature if it regenerates this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## SIMPLIFIED: with other regeneration shields up, the rider-free one is
## spent first instead of asking (CR 616.1). See docs/simplified-cards.md
## and cards/sets/vis/_creatures.gd ThisWayRegeneration.

func build() -> CardData:
	var c := CardData.new("Debt of Loyalty", "{1}{W}{W}", Mtg.CardType.INSTANT)
	c.oracle("Regenerate target creature. You gain control of that creature if it regenerates this way.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
