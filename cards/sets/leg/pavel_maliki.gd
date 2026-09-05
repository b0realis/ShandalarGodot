extends CardScript
## Pavel Maliki — {4}{B}{R} — Legendary Creature — Human — 5/3 — (leg, uncommon)
## Oracle: {B}{R}: Pavel Maliki gets +1/+0 until end of turn.
##
## Implementation: a firebreathing-shaped self PumpEffect with no tap in
## the cost, so it can be pumped as many times as there is {B}{R} to spend
## — including after blockers are declared.


func build() -> CardData:
	return CardData.new("Pavel Maliki", "{4}{B}{R}", Mtg.CardType.CREATURE) \
		.pt(5, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human"]) \
		.activated(ActivatedAbility.new(
			"{B}{R}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{B}{R}: Pavel Maliki gets +1/+0 until end of turn.")) \
		.oracle("{B}{R}: Pavel Maliki gets +1/+0 until end of turn.")
