extends CardScript
## Serra Angel — {3}{W}{W} — Creature — Angel — 4/4 (Alpha, uncommon)
## Oracle: Flying, vigilance
##
## Implementation: two printed keywords. VIGILANCE means declaring it as an
## attacker does not tap it (MtgGame.declare_attackers checks the keyword).
## Historical note: pre-6th-edition wording was "attacking does not cause
## Serra Angel to tap" — identical behavior, modeled as vigilance.


func build() -> CardData:
	return CardData.new("Serra Angel", "{3}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["angel"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE]) \
		.oracle("Flying, vigilance")
