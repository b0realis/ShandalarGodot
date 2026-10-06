extends CardScript
## Gerrard's Battle Cry — {W} — Enchantment (rare, tmp).
## Oracle: {2}{W}: Creatures you control get +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gerrard's Battle Cry", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}{W}: Creatures you control get +1/+1 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
