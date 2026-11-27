extends CardScript
## Debt of Loyalty — {1}{W}{W} — Instant (rare, wth).
## Oracle: Regenerate target creature. You gain control of that creature if it regenerates this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## With other regeneration shields up, the creature's controller chooses
## which one a destruction uses (CR 616.1); control changes only with this
## one (cards/sets/vis/_creatures.gd ThisWayRegeneration).
## SIMPLIFIED (docs/simplified-cards.md, "Debt of Loyalty"): for lethal
## combat damage a human seat is not asked — the rider-free shield is used
## first.

func build() -> CardData:
	var c := CardData.new("Debt of Loyalty", "{1}{W}{W}", Mtg.CardType.INSTANT)
	c.oracle("Regenerate target creature. You gain control of that creature if it regenerates this way.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
