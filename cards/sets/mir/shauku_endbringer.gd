extends CardScript
## Shauku, Endbringer — {5}{B}{B} — Legendary Creature — Vampire (rare, mir).
## Oracle: Flying
##         Shauku can't attack if there's another creature on the battlefield.
##         At the beginning of your upkeep, you lose 3 life.
##         {T}: Exile target creature and put a +1/+1 counter on Shauku.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shauku, Endbringer", "{5}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["vampire"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nShauku can't attack if there's another creature on the battlefield.\nAt the beginning of your upkeep, you lose 3 life.\n{T}: Exile target creature and put a +1/+1 counter on Shauku.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
