extends CardScript
## Grollub — {2}{B} — Creature — Beast (common, exo).
## Oracle: Whenever this creature is dealt damage, each opponent gains that much life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grollub", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["beast"])
	c.oracle("Whenever this creature is dealt damage, each opponent gains that much life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
