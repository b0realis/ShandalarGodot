extends CardScript
## Dauthi Trapper — {2}{B} — Creature — Dauthi Minion (uncommon, sth).
## Oracle: {T}: Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Trapper", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dauthi","minion"])
	c.oracle("{T}: Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
