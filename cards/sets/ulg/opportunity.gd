extends CardScript
## Opportunity — {4}{U}{U} — Instant (uncommon, ulg).
## Oracle: Target player draws four cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opportunity", "{4}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Target player draws four cards.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
