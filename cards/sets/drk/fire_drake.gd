extends CardScript
## Fire Drake — {1}{R}{R} — Creature — Drake — 1/2 — (drk, uncommon)
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn. Activate only
##         once each turn.
##
## Implementation: firebreathing with the per_turn(1) activation cap —
## the engine tracks uses per instance and resets them every cleanup.


func build() -> CardData:
	return CardData.new("Fire Drake", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["drake"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{R}: This creature gets +1/+0 until end of turn. Activate only once each turn.").per_turn(1)) \
		.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn. Activate only once each turn.")
