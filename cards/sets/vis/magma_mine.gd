extends CardScript
## Magma Mine — {1} — Artifact (uncommon, vis).
## Oracle: {4}: Put a pressure counter on this artifact.
##         {T}, Sacrifice this artifact: It deals damage equal to the number of pressure counters on it to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Magma Mine", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{4}: Put a pressure counter on this artifact.\n{T}, Sacrifice this artifact: It deals damage equal to the number of pressure counters on it to any target.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
