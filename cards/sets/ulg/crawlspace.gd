extends CardScript
## Crawlspace — {3} — Artifact (rare, ulg).
## Oracle: No more than two creatures can attack you each combat.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crawlspace", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("No more than two creatures can attack you each combat.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
