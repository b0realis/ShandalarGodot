extends CardScript
## Bloodshot Cyclops — {5}{R} — Creature — Cyclops Giant (rare, uds).
## Oracle: {T}, Sacrifice a creature: This creature deals damage equal to the sacrificed creature's power to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bloodshot Cyclops", "{5}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["cyclops","giant"])
	c.oracle("{T}, Sacrifice a creature: This creature deals damage equal to the sacrificed creature's power to any target.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
