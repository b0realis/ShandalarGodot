extends CardScript
## Touchstone — {2} — Artifact (uncommon, wth).
## Oracle: {T}: Tap target artifact you don't control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Touchstone", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Tap target artifact you don't control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
