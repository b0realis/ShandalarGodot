extends CardScript
## Cold Storage — {4} — Artifact (rare, tmp).
## Oracle: {3}: Exile target creature you control.
##         Sacrifice this artifact: Return each creature card exiled with this artifact to the battlefield under your control.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cold Storage", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}: Exile target creature you control.\nSacrifice this artifact: Return each creature card exiled with this artifact to the battlefield under your control.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
