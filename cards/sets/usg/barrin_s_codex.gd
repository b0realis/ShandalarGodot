extends CardScript
## Barrin's Codex — {4} — Artifact — Book (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a page counter on this artifact.
##         {4}, {T}, Sacrifice this artifact: Draw X cards, where X is the number of page counters on this artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barrin's Codex", "{4}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("At the beginning of your upkeep, you may put a page counter on this artifact.\n{4}, {T}, Sacrifice this artifact: Draw X cards, where X is the number of page counters on this artifact.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
