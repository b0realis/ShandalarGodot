extends CardScript
## Caverns of Despair — {2}{R}{R} — World Enchantment — (leg, rare)
## Oracle: No more than two creatures can attack each combat.
##         No more than two creatures can block each combat.
##
## Implementation: a static setting MtgGame.max_attackers and
## max_blockers, which declare_attackers/declare_blockers refuse to
## exceed. Both caps are rebuilt from scratch every recalculation, so
## destroying the Caverns lifts them immediately. A WORLD permanent
## (CR 704.5k). The classic anti-swarm prison.


func build() -> CardData:
	return CardData.new("Caverns of Despair", "{2}{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(
			_apply,
			"No more than two creatures can attack each combat. No more than two "
			+ "creatures can block each combat.")) \
		.oracle("No more than two creatures can attack each combat.\nNo more than two "
			+ "creatures can block each combat.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.max_attackers = 2
	game.max_blockers = 2
