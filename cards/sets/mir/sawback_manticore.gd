extends CardScript
## Sawback Manticore — {3}{R}{G} — Creature — Manticore (rare, mir).
## Oracle: {4}: This creature gains flying until end of turn.
##         {1}: This creature deals 2 damage to target attacking or blocking creature. Activate only if this creature is attacking or blocking and only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sawback Manticore", "{3}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["manticore"])
	c.oracle("{4}: This creature gains flying until end of turn.\n{1}: This creature deals 2 damage to target attacking or blocking creature. Activate only if this creature is attacking or blocking and only once each turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
