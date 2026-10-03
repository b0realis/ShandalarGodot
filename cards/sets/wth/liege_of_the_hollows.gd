extends CardScript
## Liege of the Hollows — {2}{G}{G} — Creature — Spirit (rare, wth).
## Oracle: When this creature dies, each player may pay any amount of mana. Then each player creates a number of 1/1 green Squirrel creature tokens equal to the amount of mana they paid this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Liege of the Hollows", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["spirit"])
	c.oracle("When this creature dies, each player may pay any amount of mana. Then each player creates a number of 1/1 green Squirrel creature tokens equal to the amount of mana they paid this way.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
