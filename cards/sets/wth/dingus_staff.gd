extends CardScript
## Dingus Staff — {4} — Artifact (uncommon, wth).
## Oracle: Whenever a creature dies, this artifact deals 2 damage to that creature's controller.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dingus Staff", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a creature dies, this artifact deals 2 damage to that creature's controller.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
