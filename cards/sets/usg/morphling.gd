extends CardScript
## Morphling — {3}{U}{U} — Creature — Shapeshifter (rare, usg).
## Oracle: {U}: Untap this creature.
##         {U}: This creature gains flying until end of turn.
##         {U}: This creature gains shroud until end of turn. (It can't be the target of spells or abilities.)
##         {1}: This creature gets +1/-1 until end of turn.
##         {1}: This creature gets -1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Morphling", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["shapeshifter"])
	c.oracle("{U}: Untap this creature.\n{U}: This creature gains flying until end of turn.\n{U}: This creature gains shroud until end of turn. (It can't be the target of spells or abilities.)\n{1}: This creature gets +1/-1 until end of turn.\n{1}: This creature gets -1/+1 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
