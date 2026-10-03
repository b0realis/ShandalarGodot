extends CardScript
## Abyssal Hunter — {3}{B} — Creature — Human Assassin (rare, mir).
## Oracle: {B}, {T}: Tap target creature. This creature deals damage equal to its power to that creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abyssal Hunter", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","assassin"])
	c.oracle("{B}, {T}: Tap target creature. This creature deals damage equal to its power to that creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
