extends CardScript
## Warrior en-Kor — {W}{W} — Creature — Kor Warrior Knight (uncommon, sth).
## Oracle: {0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Warrior en-Kor", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["kor","warrior","knight"])
	c.oracle("{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
