extends CardScript
## Endoskeleton — {2} — Artifact (uncommon, usg).
## Oracle: You may choose not to untap this artifact during your untap step.
##         {2}, {T}: Target creature gets +0/+3 for as long as this artifact remains tapped.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Endoskeleton", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("You may choose not to untap this artifact during your untap step.\n{2}, {T}: Target creature gets +0/+3 for as long as this artifact remains tapped.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
