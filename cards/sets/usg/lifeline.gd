extends CardScript
## Lifeline — {5} — Artifact (rare, usg).
## Oracle: Whenever a creature dies, if another creature is on the battlefield, return the first card to the battlefield under its owner's control at the beginning of the next end step.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lifeline", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a creature dies, if another creature is on the battlefield, return the first card to the battlefield under its owner's control at the beginning of the next end step.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
