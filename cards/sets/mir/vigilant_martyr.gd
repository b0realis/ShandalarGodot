extends CardScript
## Vigilant Martyr — {W} — Creature — Human Cleric (uncommon, mir).
## Oracle: Sacrifice this creature: Regenerate target creature.
##         {W}{W}, {T}, Sacrifice this creature: Counter target spell that targets an enchantment.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vigilant Martyr", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("Sacrifice this creature: Regenerate target creature.\n{W}{W}, {T}, Sacrifice this creature: Counter target spell that targets an enchantment.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
