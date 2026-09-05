extends CardScript
## Rainbow Knights — {W}{W} — Creature — Knight — 2/1 — (past, common)
## Oracle: When Rainbow Knights comes into play, it gains protection from a
##         random color permanently.
##         {1}: First strike until end of turn.
##         {W}{W}: +0/+0, +1/+0 or +2/+0 until end of turn chosen at random.
##
## Implementation: the permanent protection grant rides on
## CardInstance.added_protection (re-applied after every characteristics
## reset, gone when the Knights leave). The third ability rolls its own
## bonus at resolution — 0, 1 or 2 power, evenly.


func build() -> CardData:
	return CardData.new("Rainbow Knights", "{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["knight"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _gain_protection,
			"When Rainbow Knights comes into play, it gains protection from a random color permanently.",
			_is_self)) \
		.activated(ActivatedAbility.new("{1}", false,
			[PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()],
			"{1}: First strike until end of turn.")) \
		.activated(ActivatedAbility.new("{W}{W}", false, [RandomBoostEffect.new()],
			"{W}{W}: +0/+0, +1/+0 or +2/+0 until end of turn chosen at random.")) \
		.oracle("When Rainbow Knights comes into play, it gains protection from a random color permanently.\n{1}: First strike until end of turn.\n{W}{W}: +0/+0, +1/+0 or +2/+0 until end of turn chosen at random.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _gain_protection(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var color := RandomEffects.color(game)
	source.added_protection |= color
	game.log_line("%s gains protection from %s" % [
		source.data.card_name, String(Mtg.COLOR_NAMES[color]).to_lower()])
	game.recalculate()
	game.check_state_based_actions()


class RandomBoostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var boost := RandomEffects.roll(game, 3)   # 0, 1 or 2
		game.continuous.add_until_eot_pump(source.id, boost, 0)
		game.log_line("%s gets +%d/+0 until end of turn" % [source.data.card_name, boost])
		game.recalculate()

	func describe() -> String:
		return "+0/+0, +1/+0 or +2/+0 until end of turn chosen at random"
