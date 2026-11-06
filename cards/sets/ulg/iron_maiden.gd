extends CardScript
## Iron Maiden — {3} — Artifact (rare, ulg).
## Oracle: At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is the number of cards in their hand minus 4.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Iron Maiden", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is the number of cards in their hand minus 4.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
