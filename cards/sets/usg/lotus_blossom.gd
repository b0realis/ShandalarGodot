extends CardScript
## Lotus Blossom — {2} — Artifact (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a petal counter on this artifact.
##         {T}, Sacrifice this artifact: Add X mana of any one color, where X is the number of petal counters on this artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lotus Blossom", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, you may put a petal counter on this artifact.\n{T}, Sacrifice this artifact: Add X mana of any one color, where X is the number of petal counters on this artifact.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
