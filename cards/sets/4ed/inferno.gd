extends CardScript
## Inferno — {5}{R}{R} — Instant — (4ed, rare)
## Oracle: Inferno deals 6 damage to each creature and each player.
##
## Implementation: DamageAllEffect at 6 with the each-player rider — the
## biggest symmetric sweep in the pool, instant speed. Untargeted, so
## protection matters only for the damage itself (CoP: Red eats one hit).


func build() -> CardData:
	return CardData.new("Inferno", "{5}{R}{R}", Mtg.CardType.INSTANT) \
		.spell(DamageAllEffect.new(6).and_each_player()) \
		.oracle("Inferno deals 6 damage to each creature and each player.")
