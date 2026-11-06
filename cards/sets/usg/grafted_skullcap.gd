extends CardScript
## Grafted Skullcap — {4} — Artifact (rare, usg).
## Oracle: At the beginning of your draw step, draw an additional card.
##         At the beginning of your end step, discard your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grafted Skullcap", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your draw step, draw an additional card.\nAt the beginning of your end step, discard your hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
