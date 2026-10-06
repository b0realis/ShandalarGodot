extends CardScript
## Dauthi Mercenary — {2}{B} — Creature — Dauthi Knight Mercenary (uncommon, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {1}{B}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Mercenary", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dauthi","knight","mercenary"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{1}{B}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
