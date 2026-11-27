extends CardScript
## Matopi Golem — {5} — Artifact Creature — Golem (uncommon, vis).
## Oracle: {1}: Regenerate this creature. When it regenerates this way, put a -1/-1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## With other regeneration shields up, its controller chooses which one a
## destruction uses (CR 616.1); the counter comes only with its own
## (cards/sets/vis/_creatures.gd ThisWayRegeneration).
## SIMPLIFIED (docs/simplified-cards.md, "Matopi Golem"): for lethal combat
## damage a human seat is not asked — the rider-free shield is used first.

func build() -> CardData:
	var c := CardData.new("Matopi Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["golem"])
	c.oracle("{1}: Regenerate this creature. When it regenerates this way, put a -1/-1 counter on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
