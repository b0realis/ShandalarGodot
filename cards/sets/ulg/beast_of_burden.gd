extends CardScript
## Beast of Burden — {6} — Artifact Creature — Golem (rare, ulg).
## Oracle: Beast of Burden's power and toughness are each equal to the number of creatures on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Beast of Burden", "{6}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["golem"])
	c.oracle("Beast of Burden's power and toughness are each equal to the number of creatures on the battlefield.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
