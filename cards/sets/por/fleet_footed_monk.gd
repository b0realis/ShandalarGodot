extends CardScript
## Fleet-Footed Monk — {1}{W} — Creature — Human Monk (Portal, 1997).
## Oracle: This creature can't be blocked by creatures with power 2 or greater.

func build() -> CardData:
	var c := CardData.new("Fleet-Footed Monk", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human", "monk"])
	c.oracle("This creature can't be blocked by creatures with power 2 or greater.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
