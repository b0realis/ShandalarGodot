extends CardScript
## Dauthi Warlord — {1}{B} — Creature — Dauthi Soldier (uncommon, exo).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Dauthi Warlord's power is equal to the number of creatures on the battlefield with shadow.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dauthi Warlord", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["dauthi","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nDauthi Warlord's power is equal to the number of creatures on the battlefield with shadow.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
