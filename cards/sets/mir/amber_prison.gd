extends CardScript
## Amber Prison — {4} — Artifact (rare, mir).
## Oracle: You may choose not to untap this artifact during your untap step.
##         {4}, {T}: Tap target artifact, creature, or land. That permanent doesn't untap during its controller's untap step for as long as this artifact remains tapped.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Amber Prison", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("You may choose not to untap this artifact during your untap step.\n{4}, {T}: Tap target artifact, creature, or land. That permanent doesn't untap during its controller's untap step for as long as this artifact remains tapped.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
