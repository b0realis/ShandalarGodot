extends CardScript
## Karn, Silver Golem — {5} — Legendary Artifact Creature — Golem (rare, usg).
## Oracle: Whenever Karn blocks or becomes blocked, it gets -4/+4 until end of turn.
##         {1}: Target noncreature artifact becomes an artifact creature with power and toughness each equal to its mana value until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Karn, Silver Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 4)
	c.with_subtypes(["golem"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Whenever Karn blocks or becomes blocked, it gets -4/+4 until end of turn.\n{1}: Target noncreature artifact becomes an artifact creature with power and toughness each equal to its mana value until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
