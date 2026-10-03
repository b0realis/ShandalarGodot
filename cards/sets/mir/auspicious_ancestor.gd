extends CardScript
## Auspicious Ancestor — {3}{W} — Creature — Human Cleric (rare, mir).
## Oracle: When this creature dies, you gain 3 life.
##         Whenever a player casts a white spell, you may pay {1}. If you do, you gain 1 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Auspicious Ancestor", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature dies, you gain 3 life.\nWhenever a player casts a white spell, you may pay {1}. If you do, you gain 1 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
