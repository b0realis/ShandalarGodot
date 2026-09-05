extends CardScript
## Vampire Bats — {B} — Creature — Bat — 0/1 — (4ed, common)
## Oracle: Flying (This creature can't be blocked except by creatures
##         with flying or reach.)
##         {B}: This creature gets +1/+0 until end of turn. Activate no
##         more than twice each turn.
##
## Implementation: capped firebreathing — per_turn(2) on the {B} pump.


func build() -> CardData:
	return CardData.new("Vampire Bats", "{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["bat"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{B}: This creature gets +1/+0 until end of turn. Activate no more than twice each turn.").per_turn(2)) \
		.oracle("Flying\n{B}: This creature gets +1/+0 until end of turn. Activate no more than twice each turn.")
