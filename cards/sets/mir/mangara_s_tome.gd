extends CardScript
## Mangara's Tome — {5} — Artifact — Book (rare, mir).
## Oracle: When this artifact enters, search your library for five cards, exile them in a face-down pile, and shuffle that pile. Then shuffle your library.
##         {2}: The next time you would draw a card this turn, instead put the top card of the exiled pile into its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mangara's Tome", "{5}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("When this artifact enters, search your library for five cards, exile them in a face-down pile, and shuffle that pile. Then shuffle your library.\n{2}: The next time you would draw a card this turn, instead put the top card of the exiled pile into its owner's hand.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
