extends CardScript
## Flowstone Sculpture — {6} — Artifact Creature — Shapeshifter (rare, tmp).
## Oracle: {2}, Discard a card: Put a +1/+1 counter on this creature or this creature gains flying, first strike, or trample. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Sculpture", "{6}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 4)
	c.with_subtypes(["shapeshifter"])
	c.oracle("{2}, Discard a card: Put a +1/+1 counter on this creature or this creature gains flying, first strike, or trample. (This effect lasts indefinitely.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
