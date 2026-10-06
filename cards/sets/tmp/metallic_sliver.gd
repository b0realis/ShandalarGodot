extends CardScript
## Metallic Sliver — {1} — Artifact Creature — Sliver (common, tmp).
## Oracle: (No rules text.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Metallic Sliver", "{1}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
