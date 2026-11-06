extends CardScript
## Umbilicus — {4} — Artifact (rare, usg).
## Oracle: At the beginning of each player's upkeep, that player may pay 2 life. If they don't, they return a permanent they control to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Umbilicus", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each player's upkeep, that player may pay 2 life. If they don't, they return a permanent they control to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
