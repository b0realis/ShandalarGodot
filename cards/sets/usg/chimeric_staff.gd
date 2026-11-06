extends CardScript
## Chimeric Staff — {4} — Artifact (rare, usg).
## Oracle: {X}: This artifact becomes an X/X Construct artifact creature until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Chimeric Staff", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{X}: This artifact becomes an X/X Construct artifact creature until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
