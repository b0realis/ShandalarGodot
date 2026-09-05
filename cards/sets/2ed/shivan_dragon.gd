extends CardScript
## Shivan Dragon — {4}{R}{R} — Creature — Dragon — 5/5 (2ed, rare)
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn.
##
## Implementation: flying + the firebreathing pattern (activated mana-only
## ability, PumpEffect.self_buff(), stackable per activation). THE iconic
## finisher of the era — and of the dos486 guide's Arzakon kill.


func build() -> CardData:
	return CardData.new("Shivan Dragon", "{4}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{R}: This creature gets +1/+0 until end of turn.")) \
		.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn.")
