extends CardScript
## Crazed Armodon — {2}{G}{G} — Creature — Elephant (rare, tmp).
## Oracle: {G}: This creature gets +3/+0 and gains trample until end of turn. Destroy this creature at the beginning of the next end step. Activate only once each turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crazed Armodon", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.oracle("{G}: This creature gets +3/+0 and gains trample until end of turn. Destroy this creature at the beginning of the next end step. Activate only once each turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
