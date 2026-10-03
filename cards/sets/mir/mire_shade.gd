extends CardScript
## Mire Shade — {1}{B} — Creature — Shade (uncommon, mir).
## Oracle: {B}, Sacrifice a Swamp: Put a +1/+1 counter on this creature. Activate only as a sorcery.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mire Shade", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["shade"])
	c.oracle("{B}, Sacrifice a Swamp: Put a +1/+1 counter on this creature. Activate only as a sorcery.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
