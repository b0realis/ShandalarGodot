extends CardScript
## Chimeric Sphere — {3} — Artifact (uncommon, wth).
## Oracle: {2}: Until end of turn, this artifact becomes a 2/1 Construct artifact creature with flying.
##         {2}: Until end of turn, this artifact becomes a 3/2 Construct artifact creature and loses flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chimeric Sphere", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}: Until end of turn, this artifact becomes a 2/1 Construct artifact creature with flying.\n{2}: Until end of turn, this artifact becomes a 3/2 Construct artifact creature and loses flying.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
