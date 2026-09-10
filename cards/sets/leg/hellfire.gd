extends CardScript
## Hellfire — {2}{B}{B}{B} — Sorcery — (leg, rare)
## Oracle: Destroy all nonblack creatures. Hellfire deals X plus 3 damage
##         to you, where X is the number of creatures that died this way.
##
## Implementation: card-local effect — the count of creatures that ACTUALLY
## died (regeneration shields save their owner from feeding the fire) is
## only knowable after the destruction, so one effect does both halves.
## Matches mage-go's Hellfire, which counts survivors out the same way.


func build() -> CardData:
	return CardData.new("Hellfire", "{2}{B}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(HellfireEffect.new()) \
		.oracle("Destroy all nonblack creatures. Hellfire deals X plus 3 damage to you, "
			+ "where X is the number of creatures that died this way.")


class HellfireEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var victims: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.B) == 0:
				victims.append(inst)
		# ONE RESOLUTION, ONE BRACKET (CR 704.3, 2026-09-10): the destroys
		# AND the burn are one resolution, so nothing is swept between two
		# victims or between the last victim and the damage. Nothing may
		# return between the two calls — a deferral left open freezes
		# state-based actions for the rest of the game, and this spell can
		# end it (the burn is often lethal to its own caster).
		game.begin_simultaneous()
		var died := 0
		for inst in victims:
			game.destroy(inst)
			if inst.zone != Mtg.Zone.BATTLEFIELD:
				died += 1   # a regenerated creature never "died this way"
		game.deal_damage(source, TargetRef.player(controller), died + 3)
		game.end_simultaneous()

	func describe() -> String:
		return "destroys all nonblack creatures, then burns you for the count plus 3"
