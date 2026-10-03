extends CardScript
## Sky Diamond — {2} — Artifact (uncommon, mir).
## Oracle: This artifact enters tapped.
##         {T}: Add {U}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sky Diamond", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("This artifact enters tapped.\n{T}: Add {U}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
