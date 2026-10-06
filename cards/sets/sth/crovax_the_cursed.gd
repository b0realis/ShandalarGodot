extends CardScript
## Crovax the Cursed — {2}{B}{B} — Legendary Creature — Vampire Noble (rare, sth).
## Oracle: Crovax enters with four +1/+1 counters on it.
##         At the beginning of your upkeep, you may sacrifice a creature. If you do, put a +1/+1 counter on Crovax. If you don't, remove a +1/+1 counter from Crovax.
##         {B}: Crovax gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crovax the Cursed", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["vampire","noble"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Crovax enters with four +1/+1 counters on it.\nAt the beginning of your upkeep, you may sacrifice a creature. If you do, put a +1/+1 counter on Crovax. If you don't, remove a +1/+1 counter from Crovax.\n{B}: Crovax gains flying until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
