extends CardScript
## Phyrexian Dreadnought — {1} — Artifact Creature — Phyrexian Dreadnought (rare, mir).
## Oracle: Trample
##         When this creature enters, sacrifice it unless you sacrifice any number of creatures with total power 12 or greater.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Dreadnought", "{1}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(12, 12)
	c.with_subtypes(["phyrexian","dreadnought"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nWhen this creature enters, sacrifice it unless you sacrifice any number of creatures with total power 12 or greater.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
