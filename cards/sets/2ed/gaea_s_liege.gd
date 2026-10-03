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
## board depending on whether the Liege is attacking, plus an ability whose
## resolution registers a FLOATING static (layer 4) bound to the Liege's id:
## ContinuousEffects.forget_instance drops it the moment the Liege leaves
## the battlefield, which is what "until this creature leaves the
## battlefield" means — and nothing else ends it. A PHASED-OUT Liege has not
## left (CR 702.26d), so its Forests stay Forests meanwhile; a Liege static
## standing in for the effect used to stop with it (the phasing audit of
## 2026-10-03, D1).


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Gaea's Liege", "{3}{G}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["avatar"]) \
		.static_ability(StaticAbility.new(_count_forests,
			"Its power and toughness are each equal to the number of Forests you (or, while attacking, the defending player) control.").setting_base_pt()) \
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


class ForestifyEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var land := game.find_instance(target.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD:
			return
		# "Until this creature leaves the battlefield": a Liege that left
		# before this resolved ends the duration before it begins (CR
		# 611.2b), and a Liege back on the battlefield is a new object the
		# old activation cannot speak for (CR 400.7) — the source-timestamp
		# guard PumpEffect uses. Until 2026-10-03 the claim was written onto
		# the dead card and came back with it.
		# A PHASED-OUT Liege has not left (CR 702.26d): the zone, not
		# is_present, is the right question here.
		if source.zone != Mtg.Zone.BATTLEFIELD or source.layer_timestamp \
				!= int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
			return
		game.continuous.add_floating_static(source, StaticAbility.new(
			_forest.bind(land.id, land.layer_timestamp),
			"%s is a Forest until Gaea's Liege leaves the battlefield." % land.data.card_name) \
				.changing_land_types(),
			ContinuousEffects.Duration.INDEFINITE, -1, false, source.id)
		game.recalculate()

	## The land it touched, while it is that same land and phased in.
	static func _forest(game: MtgGame, _source: CardInstance, land_id: int,
			stamp: int) -> void:
		var land := game.find_instance(land_id)
		if game.is_present(land) and land.layer_timestamp == stamp and land.is_land():
			land.become_basic_land_type("forest", Mtg.ManaColor.G)

	func describe() -> String:
		return "target land becomes a Forest for as long as this creature is around"
