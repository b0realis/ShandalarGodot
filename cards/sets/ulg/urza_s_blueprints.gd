extends CardScript
## Urza's Blueprints — {6} — Artifact (rare, ulg).
## Oracle: Echo {6} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         {T}: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urza's Blueprints", "{6}", Mtg.CardType.ARTIFACT)
	c.oracle("Echo {6} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\n{T}: Draw a card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
