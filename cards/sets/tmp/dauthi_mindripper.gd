extends CardScript
## Dauthi Mindripper — {3}{B} — Creature — Dauthi Minion (uncommon, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, defending player discards three cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Mindripper", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dauthi","minion"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever this creature attacks and isn't blocked, you may sacrifice it. If you do, defending player discards three cards.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
