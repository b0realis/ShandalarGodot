extends CardScript
## Helm of Possession — {4} — Artifact (rare, tmp).
## Oracle: You may choose not to untap this artifact during your untap step.
##         {2}, {T}, Sacrifice a creature: Gain control of target creature for as long as you control this artifact and this artifact remains tapped.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Helm of Possession", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("You may choose not to untap this artifact during your untap step.\n{2}, {T}, Sacrifice a creature: Gain control of target creature for as long as you control this artifact and this artifact remains tapped.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
