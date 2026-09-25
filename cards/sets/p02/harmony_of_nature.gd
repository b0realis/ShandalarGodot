extends CardScript
## Harmony of Nature — {2}{G} — Sorcery (Portal Second Age, 1998).
## Oracle: Tap any number of untapped creatures you control. You gain 4 life for each creature tapped this way.

func build() -> CardData:
	var c := CardData.new("Harmony of Nature", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Tap any number of untapped creatures you control. You gain 4 life for each creature tapped this way.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
