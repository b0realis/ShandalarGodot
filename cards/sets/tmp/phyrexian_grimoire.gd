extends CardScript
## Phyrexian Grimoire — {3} — Artifact — Book (rare, tmp).
## Oracle: {4}, {T}: Target opponent chooses one of the top two cards of your graveyard. Exile that card and put the other one into your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Grimoire", "{3}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("{4}, {T}: Target opponent chooses one of the top two cards of your graveyard. Exile that card and put the other one into your hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
