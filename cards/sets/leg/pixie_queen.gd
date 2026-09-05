extends CardScript
## Pixie Queen — {2}{G}{G} — Creature — Faerie — 1/1 — (leg, rare)
## Oracle: Flying
##         {G}{G}{G}, {T}: Target creature gains flying until end of turn.
##
## Implementation: a keyword-granting PumpEffect (+0/+0 with FLYING) on a
## three-mana tap ability. Grants to ANY creature, so it can also push an
## opposing ground blocker out of the way of your own ground attack — or,
## more usually, make a fatty unblockable.


func build() -> CardData:
	return CardData.new("Pixie Queen", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["faerie"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{G}{G}{G}", true,
			[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])],
			"{G}{G}{G}, {T}: Target creature gains flying until end of turn.")) \
		.oracle("Flying\n{G}{G}{G}, {T}: Target creature gains flying until end of turn.")
