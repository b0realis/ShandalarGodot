extends CardScript
## Wall of Corpses — {1}{B} — Creature — Wall (common, mir).
## Oracle: Defender (This creature can't attack.)
##         {B}, Sacrifice this creature: Destroy target creature this creature is blocking.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Corpses", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 2)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\n{B}, Sacrifice this creature: Destroy target creature this creature is blocking.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
