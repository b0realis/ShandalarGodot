extends CardScript
## Tethered Skirge — {2}{B} — Creature — Phyrexian Imp (uncommon, ulg).
## Oracle: Flying
##         Whenever this creature becomes the target of a spell or ability, you lose 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tethered Skirge", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature becomes the target of a spell or ability, you lose 1 life.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
