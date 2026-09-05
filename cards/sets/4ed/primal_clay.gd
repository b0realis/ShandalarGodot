extends CardScript
## Primal Clay — {4} — Artifact Creature — Shapeshifter — */* — (4ed, rare)
## Oracle: As this creature enters, it becomes your choice of a 3/3
##         artifact creature, a 2/2 artifact creature with flying, or a 1/6
##         Wall artifact creature with defender in addition to its other
##         types.
##
## Implementation: the choice is made as it enters — a real replacement, so
## the printed */* body never reaches the battlefield — and remembered on
## the instance; a base-P/T static then keeps that shape for as long as it
## is around.
##
## The shape is its controller's CHOICE, asked through their DecisionAgent
## as the Clay arrives; the hint is the engine's read of the board (the Wall
## when it is against you, the flyer when the skies are contested, the 3/3
## otherwise).


func build() -> CardData:
	return CardData.new("Primal Clay", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["shapeshifter"]) \
		.static_ability(StaticAbility.new(_wear_the_shape,
			"It is a 3/3, a 2/2 with flying, or a 1/6 Wall with defender.").setting_base_pt()) \
		.as_it_enters(_pick_a_shape) \
		.oracle("As this creature enters, it becomes your choice of a 3/3 artifact creature, a 2/2 artifact creature with flying, or a 1/6 Wall artifact creature with defender in addition to its other types. (A creature with defender can't attack.)")


## "AS this creature enters, it becomes..." — a REPLACEMENT effect
## (CR 614.1c), not a trigger: the shape is settled before the Clay is ever
## on the battlefield as anything else, so nobody gets priority to answer a
## 3/3 that is about to become a Wall. Same hook Shapeshifter, Rock Hydra,
## Wood Elemental and Nameless Race use. Corrected 2026-09-01
## (docs/audit-vs-s30.md); the header used to claim this and the code did
## not do it.
static func _pick_a_shape(game: MtgGame, source: CardInstance,
		_controller: int) -> void:
	var enemy := game.opponent_of(source.controller_id)
	var their_power := 0
	var their_flyers := 0
	for inst in game.players[enemy].battlefield:
		if not inst.is_creature():
			continue
		their_power += inst.cur_power
		if inst.has_keyword(Mtg.Keyword.FLYING):
			their_flyers += 1
	var hint := 0
	if their_power >= 6:
		hint = 2
	elif their_flyers > 0:
		hint = 1
	var pid := source.controller_id
	var picked := game.agents[pid].choose_option(game, pid,
		["a 3/3", "a 2/2 with flying", "a 1/6 Wall with defender"],
		"Choose %s's shape" % source.data.card_name, hint)
	source.memory["shape"] = ["brute", "flyer", "wall"][picked]
	game.recalculate()


static func _wear_the_shape(_game: MtgGame, source: CardInstance) -> void:
	match String(source.memory.get("shape", "brute")):
		"wall":
			source.cur_power = 1
			source.cur_toughness = 6
			if not source.cur_subtypes.has("wall"):
				source.cur_subtypes.append("wall")
			if not source.cur_keywords.has(Mtg.Keyword.DEFENDER):
				source.cur_keywords.append(Mtg.Keyword.DEFENDER)
		"flyer":
			source.cur_power = 2
			source.cur_toughness = 2
			if not source.cur_keywords.has(Mtg.Keyword.FLYING):
				source.cur_keywords.append(Mtg.Keyword.FLYING)
		_:
			source.cur_power = 3
			source.cur_toughness = 3
