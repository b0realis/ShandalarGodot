extends CardScript
## Smokestack — {4} — Artifact (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a soot counter on this artifact.
##         At the beginning of each player's upkeep, that player sacrifices a permanent of their choice for each soot counter on this artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Smokestack", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, you may put a soot counter on this artifact.\nAt the beginning of each player's upkeep, that player sacrifices a permanent of their choice for each soot counter on this artifact.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
