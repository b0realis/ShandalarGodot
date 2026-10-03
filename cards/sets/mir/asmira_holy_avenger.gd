extends CardScript
## Asmira, Holy Avenger — {2}{G}{W} — Legendary Creature — Human Cleric (rare, mir).
## Oracle: Flying
##         At the beginning of each end step, put a +1/+1 counter on Asmira for each creature put into your graveyard from the battlefield this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Asmira, Holy Avenger", "{2}{G}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","cleric"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of each end step, put a +1/+1 counter on Asmira for each creature put into your graveyard from the battlefield this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
