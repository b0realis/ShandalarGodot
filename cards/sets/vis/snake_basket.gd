extends CardScript
## Snake Basket — {4} — Artifact (rare, vis).
## Oracle: {X}, Sacrifice this artifact: Create X 1/1 green Snake creature tokens. Activate only as a sorcery.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Snake Basket", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{X}, Sacrifice this artifact: Create X 1/1 green Snake creature tokens. Activate only as a sorcery.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
