extends CardScript
## Soltari Visionary — {1}{W}{W} — Creature — Soltari Cleric (common, exo).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever this creature deals damage to a player, destroy target enchantment that player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soltari Visionary", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["soltari","cleric"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever this creature deals damage to a player, destroy target enchantment that player controls.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
