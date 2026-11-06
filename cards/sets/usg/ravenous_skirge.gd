extends CardScript
## Ravenous Skirge — {2}{B} — Creature — Phyrexian Imp (common, usg).
## Oracle: Flying
##         Whenever this creature attacks, it gets +2/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ravenous Skirge", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature attacks, it gets +2/+0 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
