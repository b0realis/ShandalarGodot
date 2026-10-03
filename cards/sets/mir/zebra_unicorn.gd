extends CardScript
## Zebra Unicorn — {2}{G}{W} — Creature — Unicorn (uncommon, mir).
## Oracle: Whenever this creature deals damage, you gain that much life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zebra Unicorn", "{2}{G}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["unicorn"])
	c.oracle("Whenever this creature deals damage, you gain that much life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
