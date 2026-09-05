extends CardScript
## Remove Enchantments — {W} — Instant — (leg, common)
## Oracle: Return to your hand all enchantments you both own and control,
##         all Auras you own attached to permanents you control, and all
##         Auras you own attached to attacking creatures your opponents
##         control. Then destroy all other enchantments you control, all
##         other Auras attached to permanents you control, and all other
##         Auras attached to attacking creatures your opponents control.
##
## Implementation: one sweep computed in two passes over the same three
## groups, exactly as printed —
##   1. enchantments you control,
##   2. Auras attached to permanents you control,
##   3. Auras attached to ATTACKING creatures your opponents control.
## Anything in those groups that you also OWN goes back to your hand; the
## rest is destroyed. That is the whole card: it saves your own Auras from
## a board wipe and blows up the Paralyze somebody else put on your creature.
##
## The membership list is taken BEFORE anything moves, so returning an Aura
## cannot change whether another Aura's host still qualifies mid-sweep.
##
## The third group is the reason this is an instant: cast it after attackers
## are declared and it eats the Aura on the creature swinging at you.


func build() -> CardData:
	return CardData.new("Remove Enchantments", "{W}", Mtg.CardType.INSTANT) \
		.spell(SweepEffect.new()) \
		.oracle("Return to your hand all enchantments you both own and control, all "
			+ "Auras you own attached to permanents you control, and all Auras you "
			+ "own attached to attacking creatures your opponents control. Then "
			+ "destroy all other enchantments you control, all other Auras attached "
			+ "to permanents you control, and all other Auras attached to attacking "
			+ "creatures your opponents control.")


class SweepEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var caught: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if not inst.is_type(Mtg.CardType.ENCHANTMENT):
				continue
			if SweepEffect._in_scope(game, inst, controller) \
					and not caught.has(inst):
				caught.append(inst)
		game.begin_simultaneous()
		for inst in caught:
			if inst.zone != Mtg.Zone.BATTLEFIELD:
				continue
			if inst.owner_id == controller:
				game.return_to_hand(inst)
			else:
				game.destroy(inst)
		game.end_simultaneous()

	## The three printed groups, in one predicate.
	static func _in_scope(game: MtgGame, inst: CardInstance,
			controller: int) -> bool:
		# Group 1 — "all enchantments you both own and control" / "all other
		# enchantments you control". An AURA IS AN ENCHANTMENT (CR 303.4), so
		# this group reaches your own Paralyze or Psychic Venom sitting on the
		# opponent's permanent; groups 2 and 3 below exist to reach Auras you
		# OWN but do not control, which is why they say nothing about control.
		if inst.controller_id == controller:
			return true
		if not inst.data.is_aura():
			return false
		var host := game.find_instance(inst.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return false
		if host.controller_id == controller:
			return true
		# "attached to attacking creatures your opponents control"
		return host.is_creature() and game.combat.attackers.has(host.id)

	func describe() -> String:
		return "returns your enchantments and destroys everyone else's on your side"
