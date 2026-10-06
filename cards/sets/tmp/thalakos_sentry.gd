extends CardScript
## Thalakos Sentry — {1}{U} — Creature — Thalakos Soldier (common, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Sentry", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["thalakos","soldier"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
