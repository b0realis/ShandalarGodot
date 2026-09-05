extends CardScript
## Evil Eye of Orms-by-Gore — {4}{B} — Creature — Eye — 3/6 — (leg, uncommon)
## Oracle: Non-Eye creatures you control can't attack.
##         This creature can't be blocked except by Walls.
##
## Implementation: two statics in one — cur_cant_attack on every non-Eye
## creature its controller owns (Akron Legionnaire's prison, tribal
## flavour), and a block RESTRICTION entry on itself so only Walls may
## stop it (Invisibility's mechanism). A 3/6 that mostly gets through,
## bought with your whole ground force.


func build() -> CardData:
	return CardData.new("Evil Eye of Orms-by-Gore", "{4}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 6) \
		.with_subtypes(["eye"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Non-Eye creatures you control can't attack. This creature can't be "
			+ "blocked except by Walls.")) \
		.oracle("Non-Eye creatures you control can't attack.\nThis creature can't be "
			+ "blocked except by Walls.")


static func _only_walls(blocker: CardInstance) -> bool:
	return blocker.has_subtype("wall")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	source.cur_block_restrictions.append({"desc": "Walls", "filter": _only_walls})
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_creature() \
				and not inst.has_subtype("eye"):
			inst.cur_cant_attack = true
