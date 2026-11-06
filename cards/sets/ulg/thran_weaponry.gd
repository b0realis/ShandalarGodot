extends CardScript
## Thran Weaponry — {4} — Artifact (rare, ulg).
## Oracle: Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         You may choose not to untap this artifact during your untap step.
##         {2}, {T}: All creatures get +2/+2 for as long as this artifact remains tapped.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Weaponry", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nYou may choose not to untap this artifact during your untap step.\n{2}, {T}: All creatures get +2/+2 for as long as this artifact remains tapped.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
