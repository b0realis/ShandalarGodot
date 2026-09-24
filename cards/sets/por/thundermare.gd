extends CardScript
## Thundermare — {5}{R} — Creature — Elemental Horse (Portal, 1997).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)
## Oracle: When this creature enters, tap all other creatures.

func build() -> CardData:
	var c := CardData.new("Thundermare", "{5}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["elemental", "horse"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)\nWhen this creature enters, tap all other creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
