extends CardScript
## Granite Gargoyle — {2}{R} — Creature — Gargoyle — 2/2 (2ed, rare)
## Oracle: Flying
##         {R}: This creature gets +0/+1 until end of turn.
##
## Implementation: flying + toughness-only firebreathing (self_buff pump).
## The +0/+1 mode matters against Earthquake and in combat math — the
## tests use it to pin that toughness pumps save from marked damage.


func build() -> CardData:
	return CardData.new("Granite Gargoyle", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["gargoyle"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpEffect.new(0, 1).self_buff()],
			"{R}: This creature gets +0/+1 until end of turn.")) \
		.oracle("Flying\n{R}: This creature gets +0/+1 until end of turn.")
