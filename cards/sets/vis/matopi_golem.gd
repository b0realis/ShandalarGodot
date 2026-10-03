extends CardScript
## Matopi Golem — {5} — Artifact Creature — Golem (uncommon, vis).
## Oracle: {1}: Regenerate this creature. When it regenerates this way, put a -1/-1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## SIMPLIFIED: with other regeneration shields up, the rider-free one is
## spent first instead of asking (CR 616.1). See docs/simplified-cards.md
## and cards/sets/vis/_creatures.gd ThisWayRegeneration.

func build() -> CardData:
	var c := CardData.new("Matopi Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["golem"])
	c.oracle("{1}: Regenerate this creature. When it regenerates this way, put a -1/-1 counter on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
