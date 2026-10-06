extends CardScript
## Soltari Monk — {W}{W} — Creature — Soltari Monk Cleric (uncommon, tmp).
## Oracle: Protection from black
##         Shadow (This creature can block or be blocked by only creatures with shadow.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Monk", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["soltari","monk","cleric"])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Protection from black\nShadow (This creature can block or be blocked by only creatures with shadow.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
