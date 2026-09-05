extends CardScript
## Pestilence — {2}{B}{B} — Enchantment (2ed, common)
## Oracle: At the beginning of the end step, if there are no creatures on
##         the battlefield, sacrifice Pestilence.
##         {B}: Pestilence deals 1 damage to each creature and each player.
##
## Implementation: two pieces —
## 1. A repeatable activated ability: DamageAllEffect(1) hitting every
##    creature (its controller's included) and both players. Multiple
##    activations in one priority window melt entire boards one point at
##    a time, exactly like the original's infamous Pestilence decks.
## 2. An END_STEP_START trigger whose condition checks for an empty
##    creature battlefield and re-checks it on resolution (an
##    intervening-if clause, CR 603.4); resolution SACRIFICES the
##    enchantment through MtgGame.sacrifice_permanent — the printed word,
##    so regeneration and indestructible are both irrelevant (CR 701.17),
##    while it still dies for dies-triggers.


func build() -> CardData:
	return CardData.new("Pestilence", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[DamageAllEffect.new(1, "each creature").and_each_player()],
			"{B}: Pestilence deals 1 damage to each creature and each player.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START,
			_sacrifice,
			"At the beginning of the end step, if there are no creatures on the battlefield, sacrifice Pestilence.",
			_no_creatures)) \
		.oracle("At the beginning of the end step, if there are no creatures on the battlefield, sacrifice Pestilence.\n{B}: Pestilence deals 1 damage to each creature and each player.")


static func _no_creatures(game: MtgGame, _source: CardInstance, _event: GameEvent) -> bool:
	for inst in game.all_battlefield():
		if inst.is_creature():
			return false
	return true


static func _sacrifice(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# Re-check at resolution (a creature may have arrived in response).
	if _no_creatures(game, source, _event) and source.zone == Mtg.Zone.BATTLEFIELD:
		# "SACRIFICE this enchantment" — not destruction: it cannot be
		# regenerated and it ignores indestructible (CR 701.17).
		game.sacrifice_permanent(source)
