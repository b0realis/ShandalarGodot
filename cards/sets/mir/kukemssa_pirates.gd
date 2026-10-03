extends CardScript
## Kukemssa Pirates — {3}{U} — Creature — Human Pirate (rare, mir).
## Oracle: Whenever this creature attacks and isn't blocked, you may gain control of target artifact defending player controls. If you do, this creature assigns no combat damage this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kukemssa Pirates", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","pirate"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may gain control of target artifact defending player controls. If you do, this creature assigns no combat damage this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
