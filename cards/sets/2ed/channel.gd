extends CardScript
## Channel — {G}{G} — Sorcery — (2ed, uncommon)
## Oracle: Until end of turn, any time you could activate a mana ability,
##         you may pay 1 life. If you do, add {C}.
##
## Implementation: Channel grants the PLAYER a mana source, not a permanent
## an ability, so it raises a flag on the seat (MtgPlayer.life_for_mana) and
## the pump itself is an ACTION on the game — MtgGame.pay_life_for_mana —
## reachable by the UI, the AI and a test through the same public API as
## every other engine action, and gated on the same timing rule
## MtgGame.tap_for_mana obeys (CR 605.3a: any time a cost could be paid,
## including in the middle of paying one).
##
## Life may be paid down to exactly 0 (CR 118.4); the state-based actions
## then do the rest, which is the entire Channel-Fireball story.
##
## The grant expires at cleanup, and the mana itself empties at the next
## step boundary like any other — Channel is a burst, not a battery.


func build() -> CardData:
	return CardData.new("Channel", "{G}{G}", Mtg.CardType.SORCERY) \
		.spell(ChannelEffect.new()) \
		.oracle("Until end of turn, any time you could activate a mana ability, "
			+ "you may pay 1 life. If you do, add {C}.")


class ChannelEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].life_for_mana = true
		game.log_line("%s opens the Channel" % game.players[controller].player_name)

	func describe() -> String:
		return "you may pay 1 life for {C} any time this turn"
