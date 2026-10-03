extends CardScript
## Crimson Roc — {4}{R} — Creature — Bird (uncommon, mir).
## Oracle: Flying
##         Whenever this creature blocks a creature without flying, this creature gets +1/+0 and gains first strike until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crimson Roc", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature blocks a creature without flying, this creature gets +1/+0 and gains first strike until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
