extends CardScript
## Dauthi Cutthroat — {1}{B} — Creature — Dauthi Minion (uncommon, exo).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         {1}{B}, {T}: Destroy target creature with shadow.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Cutthroat", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dauthi","minion"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\n{1}{B}, {T}: Destroy target creature with shadow.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
