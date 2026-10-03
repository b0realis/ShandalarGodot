extends CardScript
## Maraxus of Keld — {4}{R}{R} — Legendary Creature — Human Warrior (rare, wth).
## Oracle: Maraxus's power and toughness are each equal to the number of untapped artifacts, creatures, and lands you control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Maraxus of Keld", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["human","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Maraxus's power and toughness are each equal to the number of untapped artifacts, creatures, and lands you control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
