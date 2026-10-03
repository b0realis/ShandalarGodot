extends CardScript
## Desertion — {3}{U}{U} — Instant (rare, vis).
## Oracle: Counter target spell. If an artifact or creature spell is countered this way, put that card onto the battlefield under your control instead of into its owner's graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Desertion", "{3}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell. If an artifact or creature spell is countered this way, put that card onto the battlefield under your control instead of into its owner's graveyard.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
