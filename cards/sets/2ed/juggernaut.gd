extends CardScript
## Juggernaut — {4} — Artifact Creature — Juggernaut — 5/3 (2ed, uncommon)
## Oracle: This creature attacks each combat if able.
##         This creature can't be blocked by Walls.
##
## Implementation: MUST_ATTACK keyword (declare_attackers refuses a combat
## declaration that omits an able Juggernaut) + cant_be_blocked_by ["wall"]
## (block legality checks blocker subtypes). Colorless artifact creature,
## so Terror can't touch it and protection-from-colors never blocks it.
## THE Shandalar deck staple per the dos486 strategy guide — worth getting
## exactly right.


func build() -> CardData:
	return CardData.new("Juggernaut", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(5, 3) \
		.with_subtypes(["juggernaut"]) \
		.with_keywords([Mtg.Keyword.MUST_ATTACK]) \
		.with_cant_be_blocked_by(["wall"]) \
		.oracle("This creature attacks each combat if able.\nThis creature can't be blocked by Walls.")
