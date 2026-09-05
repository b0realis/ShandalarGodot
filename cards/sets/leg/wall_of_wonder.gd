extends CardScript
## Wall of Wonder — {2}{U}{U} — Creature — Wall — 1/5 — (leg, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {2}{U}{U}: This creature gets +4/-4 until end of turn and can
##         attack this turn as though it didn't have defender.
##
## Implementation: two effects in one ability — a self PumpEffect of
## +4/-4 and a LoseAbilityEffect.to_source() that strips DEFENDER for the
## turn. Losing the keyword and "attacking as though it didn't have it"
## are indistinguishable in this engine: defender only ever gates
## attacking (CR 702.3b).


func build() -> CardData:
	return CardData.new("Wall of Wonder", "{2}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 5) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{2}{U}{U}", false,
			[PumpEffect.new(4, -4).self_buff(),
			 LoseAbilityEffect.new([Mtg.Keyword.DEFENDER], "defender").to_source()],
			"{2}{U}{U}: Wall of Wonder gets +4/-4 until end of turn and can attack "
			+ "this turn as though it didn't have defender.")) \
		.oracle("Defender (This creature can't attack.)\n{2}{U}{U}: This creature gets "
			+ "+4/-4 until end of turn and can attack this turn as though it didn't have defender.")
