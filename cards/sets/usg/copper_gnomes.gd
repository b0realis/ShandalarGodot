extends CardScript
## Copper Gnomes — {2} — Artifact Creature — Gnome (rare, usg).
## Oracle: {4}, Sacrifice this creature: You may put an artifact card from your hand onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Copper Gnomes", "{2}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["gnome"])
	c.oracle("{4}, Sacrifice this creature: You may put an artifact card from your hand onto the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
