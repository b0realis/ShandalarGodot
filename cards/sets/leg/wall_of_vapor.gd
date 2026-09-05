extends CardScript
## Wall of Vapor — {3}{U} — Creature — Wall — 0/1 — (leg, common)
## Oracle: Defender (This creature can't attack.)
##         Prevent all damage that would be dealt to this creature by
##         creatures it's blocking.
##
## Implementation: a static installing a SOURCE-FILTERED damage immunity
## (CardInstance.cur_damage_immunity) whose predicate asks the live
## combat state whether this wall is blocking the damage source. A 0/1
## that stops anything in combat forever — but dies to any burn spell,
## which the second test pins.


func build() -> CardData:
	return CardData.new("Wall of Vapor", "{3}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all damage that would be dealt to Wall of Vapor by creatures "
			+ "it's blocking.")) \
		.oracle("Defender (This creature can't attack.)\nPrevent all damage that "
			+ "would be dealt to this creature by creatures it's blocking.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_immunity.append({
		"desc": "creatures it's blocking",
		"filter": _is_blocked_by.bind(source.id)})


static func _is_blocked_by(game: MtgGame, damager: CardInstance,
		wall_id: int) -> bool:
	return game.combat.is_blocking(wall_id, damager.id)
