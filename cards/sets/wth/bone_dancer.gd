extends CardScript
## Bone Dancer — {1}{B}{B} — Creature — Zombie (rare, wth).
## Oracle: Whenever this creature attacks and isn't blocked, you may put the top creature card of defending player's graveyard onto the battlefield under your control. If you do, this creature assigns no combat damage this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bone Dancer", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["zombie"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may put the top creature card of defending player's graveyard onto the battlefield under your control. If you do, this creature assigns no combat damage this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
