extends CardScript
## Mindbender Spores — {2}{G} — Creature — Fungus Wall (rare, mir).
## Oracle: Defender (This creature can't attack.)
##         Flying
##         Whenever this creature blocks a creature, put four fungus counters on that creature. The creature gains "This creature doesn't untap during your untap step if it has a fungus counter on it" and "At the beginning of your upkeep, remove a fungus counter from this creature."
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mindbender Spores", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["fungus","wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FLYING])
	c.oracle("Defender (This creature can't attack.)\nFlying\nWhenever this creature blocks a creature, put four fungus counters on that creature. The creature gains \"This creature doesn't untap during your untap step if it has a fungus counter on it\" and \"At the beginning of your upkeep, remove a fungus counter from this creature.\"")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
