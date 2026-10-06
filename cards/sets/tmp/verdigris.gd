extends CardScript
## Verdigris — {2}{G} — Instant (uncommon, tmp).
## Oracle: Destroy target artifact.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Verdigris", "{2}{G}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target artifact.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
