extends CardScript
## Shaman en-Kor — {1}{W} — Creature — Kor Cleric Shaman (rare, sth).
## Oracle: {0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.
##         {1}{W}: The next time a source of your choice would deal damage to target creature this turn, that damage is dealt to this creature instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shaman en-Kor", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["kor","cleric","shaman"])
	c.oracle("{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.\n{1}{W}: The next time a source of your choice would deal damage to target creature this turn, that damage is dealt to this creature instead.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
