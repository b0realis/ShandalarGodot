extends CardScript
## Teferi's Puzzle Box — {4} — Artifact (rare, vis).
## Oracle: At the beginning of each player's draw step, that player puts the cards in their hand on the bottom of their library in any order, then draws that many cards.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Puzzle Box", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each player's draw step, that player puts the cards in their hand on the bottom of their library in any order, then draws that many cards.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
