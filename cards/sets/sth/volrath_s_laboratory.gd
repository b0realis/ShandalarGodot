extends CardScript
## Volrath's Laboratory — {5} — Artifact (rare, sth).
## Oracle: As this artifact enters, choose a color and a creature type.
##         {5}, {T}: Create a 2/2 creature token of the chosen color and type.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Laboratory", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("As this artifact enters, choose a color and a creature type.\n{5}, {T}: Create a 2/2 creature token of the chosen color and type.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
