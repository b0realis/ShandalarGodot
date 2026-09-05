extends CardScript
## Reverberation — {2}{U}{U} — Instant — (leg, rare)
## Oracle: All damage that would be dealt this turn by target sorcery spell
##         is dealt to that spell's controller instead.
##
## Implementation: a replacement on the SOURCE rather than on a victim
## (CardInstance.damage_all_redirect_to, new), applied by MtgGame before
## anything about the target is considered — because every point that
## sorcery deals, to anyone, goes the same way.
##
## It is a real redirection (MtgGame.redirect_damage), so the caster's own
## prevention still gets a say on what lands on them, and the redirected
## packet is marked as such so it cannot be turned around a second time.
##
## The target is the SORCERY SPELL on the stack, so this is an answer held
## up in response: a Fireball or an Earthquake aimed anywhere becomes a
## Fireball aimed at its caster. It does nothing to an instant, and nothing
## to a permanent's ability.
##
## "This turn" outlives the spell itself, which is why the flag is on the
## instance and is cleared at cleanup: a countered or resolved sorcery is
## already gone, and only the damage it deals is affected either way.


func build() -> CardData:
	return CardData.new("Reverberation", "{2}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(ReverbEffect.new()) \
		.oracle("All damage that would be dealt this turn by target sorcery spell "
			+ "is dealt to that spell's controller instead.")


class ReverbEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # a redirection: legal in the window
		target_spec = TargetSpec.spell("target sorcery spell",
			ReverbEffect._is_sorcery)

	static func _is_sorcery(inst: CardInstance) -> bool:
		return inst.data.is_type(Mtg.CardType.SORCERY)

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		var item := game.find_stack_item(spell)
		var caster: int = spell.controller_id if item == null else item.controller
		spell.damage_all_redirect_to = caster
		game.log_line("%s will reverberate onto %s" % [
			spell.data.card_name, game.players[caster].player_name])

	func describe() -> String:
		return "a sorcery's damage is dealt to its own controller"
