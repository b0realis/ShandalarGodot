extends CardScript
## Clergy of the Holy Nimbus — {W} — Creature — Human Cleric — 1/1 — (leg, common)
## Oracle: If this creature would be destroyed, regenerate it.
##         {1}: This creature can't be regenerated this turn. Only your
##         opponents may activate this ability.
##
## Implementation: the permanent regeneration is a static that tops the
## Clergy's regeneration shield back up to one on every recalculation —
## so every destruction is replaced, exactly as printed, and the shield
## never runs out. The switch-off is an ActivatedAbility marked
## .opponent_activated(): MtgGame lets the OPPONENT (and only the
## opponent) pay {1} to set the turn's regeneration ban, which
## MtgGame.destroy honours over any shield.


func build() -> CardData:
	return CardData.new("Clergy of the Holy Nimbus", "{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.static_ability(StaticAbility.new(
			_apply, "If Clergy of the Holy Nimbus would be destroyed, regenerate it.")) \
		.activated(ActivatedAbility.new(
			"{1}", false, [BanRegenerationEffect.new()],
			"{1}: Clergy of the Holy Nimbus can't be regenerated this turn. Only your "
			+ "opponents may activate this ability.") \
			.opponent_activated()) \
		.oracle("If this creature would be destroyed, regenerate it.\n{1}: This "
			+ "creature can't be regenerated this turn. Only your opponents may "
			+ "activate this ability.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	if source.regeneration_shields < 1:
		source.regeneration_shields = 1


class BanRegenerationEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone != Mtg.Zone.BATTLEFIELD:
			return
		source.regeneration_banned_this_turn = true
		game.log_line("%s can't be regenerated this turn" % source.data.card_name)

	func describe() -> String:
		return "this creature can't be regenerated this turn"
