extends CardScript
## Angelic Page — {1}{W} — Creature — Angel Spirit (common, usg).
## Oracle: Flying
##         {T}: Target attacking or blocking creature gets +1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angelic Page", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["angel","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: Target attacking or blocking creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
