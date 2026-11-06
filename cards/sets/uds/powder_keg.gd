extends CardScript
## Powder Keg — {2} — Artifact (rare, uds).
## Oracle: At the beginning of your upkeep, you may put a fuse counter on this artifact.
##         {T}, Sacrifice this artifact: Destroy each artifact and creature with mana value equal to the number of fuse counters on this artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Powder Keg", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, you may put a fuse counter on this artifact.\n{T}, Sacrifice this artifact: Destroy each artifact and creature with mana value equal to the number of fuse counters on this artifact.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
