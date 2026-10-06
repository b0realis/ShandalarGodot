extends CardScript
## Angelic Protector — {3}{W} — Creature — Angel (uncommon, tmp).
## Oracle: Flying
##         Whenever this creature becomes the target of a spell or ability, this creature gets +0/+3 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angelic Protector", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature becomes the target of a spell or ability, this creature gets +0/+3 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
