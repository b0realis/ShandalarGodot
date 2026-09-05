extends CardScript
## Gaea's Liege — {3}{G}{G}{G} — Creature — Avatar — */* — (2ed, rare)
## Oracle: As long as Gaea's Liege isn't attacking, its power and toughness
##         are each equal to the number of Forests you control. As long as
##         Gaea's Liege is attacking, its power and toughness are each equal
##         to the number of Forests defending player controls.
##         {T}: Target land becomes a Forest until this creature leaves the
##         battlefield.
##
## Implementation: a characteristic-defining static that counts the right
## board depending on whether the Liege is attacking, plus an ability that
## records land ids in the Liege's own memory — a second static then turns
## each of those lands into a Forest every recalculation, so the change
## lasts exactly as long as the Liege is on the battlefield, which is what
## "until this creature leaves the battlefield" means.


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Gaea's Liege", "{3}{G}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["avatar"]) \
		.static_ability(StaticAbility.new(_count_forests,
			"Its power and toughness are each equal to the number of Forests you (or, while attacking, the defending player) control.").setting_base_pt()) \
		.static_ability(StaticAbility.new(_hold_the_forests,
			"Lands it has touched are Forests for as long as it is on the battlefield.") \
			.changing_land_types()) \
		.activated(ActivatedAbility.new("", true,
			[ForestifyEffect.new(TargetSpec.new(
				TargetSpec.Kind.PERMANENT, "target land", _is_land))],
			"{T}: Target land becomes a Forest until this creature leaves the battlefield.")) \
		.oracle("As long as Gaea's Liege isn't attacking, its power and toughness are each equal to the number of Forests you control. As long as Gaea's Liege is attacking, its power and toughness are each equal to the number of Forests defending player controls.\n{T}: Target land becomes a Forest until this creature leaves the battlefield.")


static func _count_forests(game: MtgGame, source: CardInstance) -> void:
	var whose := source.controller_id
	if game.combat.attackers.has(source.id):
		whose = game.opponent_of(source.controller_id)
	var forests := 0
	for inst in game.players[whose].battlefield:
		if inst.is_land() and inst.has_subtype("forest"):
			forests += 1
	source.cur_power = forests
	source.cur_toughness = forests


static func _hold_the_forests(game: MtgGame, source: CardInstance) -> void:
	for land_id in Array(source.memory.get("forests", [])):
		var land := game.find_instance(int(land_id))
		if land != null and land.zone == Mtg.Zone.BATTLEFIELD and land.is_land():
			land.become_basic_land_type("forest", Mtg.ManaColor.G)


class ForestifyEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var land := game.find_instance(target.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD:
			return
		var claimed: Array = source.memory.get("forests", [])
		if not claimed.has(land.id):
			claimed.append(land.id)
		source.memory["forests"] = claimed
		game.recalculate()

	func describe() -> String:
		return "target land becomes a Forest for as long as this creature is around"
