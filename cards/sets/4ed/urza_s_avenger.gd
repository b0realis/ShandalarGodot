extends CardScript
## Urza's Avenger — {6} — Artifact Creature — Shapeshifter — 4/4 — (4ed, rare)
## Oracle: {0}: This creature gets -1/-1 and gains your choice of banding,
##         flying, first strike, or trample until end of turn.
##
## Implementation: four free abilities, one per keyword — activated
## abilities have no modes in this engine, and four entries read the same in
## a menu. Each shrinks the Avenger by 1/1, so the fourth activation of a
## 4/4 leaves a 0/0 and it dies, exactly as printed.


func build() -> CardData:
	var avenger := CardData.new("Urza's Avenger", "{6}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["shapeshifter"])
	var names := {
		Mtg.Keyword.BANDING: "banding", Mtg.Keyword.FLYING: "flying",
		Mtg.Keyword.FIRST_STRIKE: "first strike", Mtg.Keyword.TRAMPLE: "trample",
	}
	for keyword in names:
		avenger.activated(ActivatedAbility.new("", false,
			[PumpEffect.new(-1, -1, [keyword]).self_buff()],
			"{0}: This creature gets -1/-1 and gains %s until end of turn." % names[keyword]))
	return avenger.oracle("{0}: This creature gets -1/-1 and gains your choice of banding, flying, first strike, or trample until end of turn.")
