extends CardScript
## Vhati il-Dal — {2}{B}{G} — Legendary Creature — Human Warrior (rare, tmp).
## Oracle: {T}: Until end of turn, target creature has base power 1 or base toughness 1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vhati il-Dal", "{2}{B}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Until end of turn, target creature has base power 1 or base toughness 1.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
