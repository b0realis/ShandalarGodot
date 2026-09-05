extends CardScript
## Emerald Dragonfly — {1}{G} — Creature — Insect — 1/1 — (leg, common)
## Oracle: Flying
##         {G}{G}: This creature gains first strike until end of turn.
##
## Implementation: a self PumpEffect of +0/+0 that grants FIRST_STRIKE —
## the engine's keyword-granting pump. Green rarely gets first strike;
## a 1/1 flier that wins fights with other 1/1 fliers is the point.


func build() -> CardData:
	return CardData.new("Emerald Dragonfly", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["insect"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{G}{G}", false,
			[PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()],
			"{G}{G}: Emerald Dragonfly gains first strike until end of turn.")) \
		.oracle("Flying\n{G}{G}: This creature gains first strike until end of turn.")
