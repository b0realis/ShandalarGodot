extends CardScript
## Tuknir Deathlock — {R}{R}{G}{G} — Legendary Creature — Human Wizard — 2/2 — (leg, rare)
## Oracle: Flying
##         {R}{G}, {T}: Target creature gets +2/+2 until end of turn.
##
## Implementation: printed flying plus a tap-and-two-mana PumpEffect. The
## boost lands on any creature (either side's — the printed text has no
## "you control" clause). Matches mage-go.


func build() -> CardData:
	return CardData.new("Tuknir Deathlock", "{R}{R}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "wizard"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{R}{G}", true,
			[PumpEffect.new(2, 2)],
			"{R}{G}, {T}: Target creature gets +2/+2 until end of turn.")) \
		.oracle("Flying\n{R}{G}, {T}: Target creature gets +2/+2 until end of turn.")
