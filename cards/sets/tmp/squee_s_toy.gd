extends CardScript
## Squee's Toy — {1} — Artifact (common, tmp).
## Oracle: {T}: Prevent the next 1 damage that would be dealt to target creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Squee's Toy", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Prevent the next 1 damage that would be dealt to target creature this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
