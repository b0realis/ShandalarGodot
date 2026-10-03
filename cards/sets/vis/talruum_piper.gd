extends CardScript
## Talruum Piper — {4}{R} — Creature — Minotaur (uncommon, vis).
## Oracle: All creatures with flying able to block this creature do so.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Talruum Piper", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["minotaur"])
	c.oracle("All creatures with flying able to block this creature do so.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
