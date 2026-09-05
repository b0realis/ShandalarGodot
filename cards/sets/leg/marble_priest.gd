extends CardScript
## Marble Priest — {5} — Artifact Creature — Cleric — 3/3 — (leg, uncommon)
## Oracle: All Walls able to block this creature do so.
##         Prevent all combat damage that would be dealt to this creature
##         by Walls.
##
## Implementation: Lure's forced-blocking flag NARROWED to Walls
## (cur_must_be_blocked + cur_must_be_blocked_filter), plus a
## source-filtered damage immunity against Walls. It drags the defender's
## whole wall of Walls into a fight it cannot lose — and out of the way
## of everything else you are attacking with.


func build() -> CardData:
	return CardData.new("Marble Priest", "{5}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["cleric"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"All Walls able to block Marble Priest do so, and Walls can't damage it.")) \
		.oracle("All Walls able to block this creature do so.\nPrevent all combat "
			+ "damage that would be dealt to this creature by Walls.")


static func _is_wall(blocker: CardInstance) -> bool:
	return blocker.has_subtype("wall")


static func _wall_damage(_game: MtgGame, damager: CardInstance) -> bool:
	return damager.has_subtype("wall")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_must_be_blocked = true
	source.cur_must_be_blocked_filter = _is_wall
	source.cur_damage_immunity.append(
		{"desc": "Walls", "filter": _wall_damage, "combat": true})   # COMBAT damage only
