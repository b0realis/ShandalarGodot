extends CardScript
## Blood of the Martyr — {W}{W}{W} — Instant — (drk, uncommon)
## Oracle: Until end of turn, if damage would be dealt to any creature, you
##         may have that damage dealt to you instead.
##
## Implementation: a seat-level replacement for the whole turn
## (MtgPlayer.may_take_creature_damage, new), applied by MtgGame before
## every prevention gate on a creature and offered PER PACKET — the printed
## word is "may", so the choice really is made each time, through the
## ordinary DecisionAgent funnel.
##
## ANY creature: yours, theirs, a token, one in combat, one being shot by a
## Prodigal Sorcerer. That is the printed word, and it is what makes this a
## combat trick rather than a fog — you take the blows your blockers would
## have died to, and their creatures survive too if you let them.
##
## The redirection is a real one (MtgGame.redirect_damage), so what lands on
## you is the same damage: your own Circle of Protection can then answer it,
## and the packet that reaches you is marked as a redirect so the offer is
## not made a second time.
##
## Three white mana at instant speed, and it lasts the whole turn — the
## `Duel.hlp` prevention window lists this family among the effects that may
## be used while damage is on the table.


func build() -> CardData:
	return CardData.new("Blood of the Martyr", "{W}{W}{W}", Mtg.CardType.INSTANT) \
		.spell(MartyrEffect.new()) \
		.oracle("Until end of turn, if damage would be dealt to any creature, you "
			+ "may have that damage dealt to you instead.")


class MartyrEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # a redirection: legal in the window

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].may_take_creature_damage = true
		game.log_line("%s offers to take every blow this turn"
			% game.players[controller].player_name)

	func describe() -> String:
		return "you may take damage aimed at any creature this turn"
