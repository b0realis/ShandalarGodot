extends CardScript
## Fastbond — {G} — Enchantment — (2ed, rare)
## Oracle: You may play any number of lands on each of your turns.
##         Whenever you play a land, if it wasn't the first land you
##         played this turn, this enchantment deals 1 damage to you.
##
## Implementation: a static registering its controller in
## MtgGame.unlimited_land_plays (play_land then stops counting), plus a
## LAND_PLAYED trigger whose intervening "if" checks the per-turn land
## counter — which play_land has already incremented, so "not the first"
## means the counter is 2 or more.


func build() -> CardData:
	return CardData.new("Fastbond", "{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply, "You may play any number of lands on each of your turns.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LAND_PLAYED, _sting,
			"Whenever you play a land, if it wasn't the first land you played this "
			+ "turn, Fastbond deals 1 damage to you.",
			_extra_land)) \
		.oracle("You may play any number of lands on each of your turns.\nWhenever "
			+ "you play a land, if it wasn't the first land you played this turn, this "
			+ "enchantment deals 1 damage to you.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	game.unlimited_land_plays[source.controller_id] = true


static func _extra_land(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var pid := int(event.data["controller"])
	return pid == source.controller_id and game.players[pid].lands_played_this_turn >= 2


static func _sting(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(source.controller_id), 1)
