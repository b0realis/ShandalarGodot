extends CardScript
## Soltari Priest — {W}{W} — Creature — Soltari Cleric (uncommon, tmp).
## Oracle: Protection from red
##         Shadow (This creature can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Priest", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["soltari","cleric"])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Protection from red\nShadow (This creature can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
