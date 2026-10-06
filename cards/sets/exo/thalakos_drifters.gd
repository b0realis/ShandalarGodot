extends CardScript
## Thalakos Drifters — {2}{U}{U} — Creature — Thalakos (rare, exo).
## Oracle: Discard a card: This creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Drifters", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["thalakos"])
	c.oracle("Discard a card: This creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
