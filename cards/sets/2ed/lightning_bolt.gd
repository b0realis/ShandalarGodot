extends CardScript
## Lightning Bolt — {R} — Instant (Alpha, common)
## Oracle: Lightning Bolt deals 3 damage to any target.
##
## Implementation: one DamageEffect with an "any target" spec. Damage to a
## creature marks damage (SBA kills at lethal); damage to a player reduces
## life — both handled by MtgGame.deal_damage, nothing card-specific here.
## Tests: tests/cards/test_limited_cards.gd (kills a 2/2; burns a player;
## fizzles when its only target dies first).


func build() -> CardData:
	return CardData.new("Lightning Bolt", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(3).any_target()) \
		.oracle("Lightning Bolt deals 3 damage to any target.")
