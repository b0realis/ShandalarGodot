extends CardScript
## Bubble Matrix — {4} — Artifact (rare, wth).
## Oracle: Prevent all damage that would be dealt to creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bubble Matrix", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("Prevent all damage that would be dealt to creatures.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
