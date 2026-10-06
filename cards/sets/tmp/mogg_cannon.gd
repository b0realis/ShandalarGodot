extends CardScript
## Mogg Cannon — {2} — Artifact (uncommon, tmp).
## Oracle: {T}: Target creature you control gets +1/+0 and gains flying until end of turn. Destroy that creature at the beginning of the next end step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Cannon", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Target creature you control gets +1/+0 and gains flying until end of turn. Destroy that creature at the beginning of the next end step.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
