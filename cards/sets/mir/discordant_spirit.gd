extends CardScript
## Discordant Spirit — {2}{B}{R} — Creature — Spirit (rare, mir).
## Oracle: At the beginning of each end step, if it's an opponent's turn, put a +1/+1 counter on this creature for each 1 damage dealt to you this turn.
##         At the beginning of your end step, remove all +1/+1 counters from this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Discordant Spirit", "{2}{B}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["spirit"])
	c.oracle("At the beginning of each end step, if it's an opponent's turn, put a +1/+1 counter on this creature for each 1 damage dealt to you this turn.\nAt the beginning of your end step, remove all +1/+1 counters from this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
