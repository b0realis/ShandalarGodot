extends CardScript
## Knight of Dawn — {1}{W}{W} — Creature — Human Knight (uncommon, tmp).
## Oracle: First strike
##         {W}{W}: This creature gains protection from the color of your choice until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Knight of Dawn", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\n{W}{W}: This creature gains protection from the color of your choice until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
