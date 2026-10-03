extends CardScript
## Mtenda Griffin — {3}{W} — Creature — Griffin (uncommon, mir).
## Oracle: Flying
##         {W}, {T}: Return this creature to its owner's hand and return target Griffin card from your graveyard to your hand. Activate only during your upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mtenda Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{W}, {T}: Return this creature to its owner's hand and return target Griffin card from your graveyard to your hand. Activate only during your upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
