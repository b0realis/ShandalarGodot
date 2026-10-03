extends RefCounted
## Weatherlight (_artifacts, Pack 8). Noncreature artifacts and their activated or static abilities.
##
## Bubble Matrix — a static that raises every creature's
##   cur_prevent_all_damage_taken flag (CR 615: a prevention effect, so the
##   damage-prevention chain and "can't be prevented" damage behave as they
##   do for every other shield). Damage to players is untouched.
## Chimeric Sphere / Xanthic Statue — AnimateSelfEffect plus layer-6
##   keyword grants/losses stamped after the animation (CR 613.7): the
##   later of the Sphere's two forms decides both its P/T and its flying.
## Dingus Staff — a DIES trigger over every creature (last known types,
##   CR 608.2h); the damage goes to the controller the creature died under,
##   and is dealt even if the Staff has left by then.
## Mana Web — a TAPPED_FOR_MANA trigger for an opponent's land. It adds no
##   mana, so it is NOT a mana ability (CR 605.1b) and uses the stack; the
##   tapped land's possible mana types are read as it resolves (its last
##   known types if it has gone, captured as it triggered).
## Phyrexian Furnace — the bottom of a graveyard is index 0 (cards are
##   appended on top). The sacrifice ability is one object: if its only
##   target has left the graveyard it is countered and draws nothing
##   (CR 608.2b).
## Thran Forge — a PumpEffect whose type half is a floating layer-4 static
##   bound to the creature (CR 400.7: a new object is not an artifact).
## Thran Tome — reveal to both seats, the TARGETED opponent's agent picks,
##   the pick is milled through public helpers, then two draws.
## Touchstone — TapEffect on an artifact another player controls.
## Well of Knowledge — any player, only in their own draw step: the timing
##   riders are judged against the ACTIVATOR (MtgGame.ability_timing_refusal),
##   who controls the ability and draws (CR 602.2, 113.8).
## Bösium Strip — a graveyard-cast permission for the activator, this turn
##   only, top card only; a spell cast with it is exiled wherever it would go
##   to a graveyard (resolved, fizzled or countered — MtgGame.grant_graveyard_cast).
## Jabari's Banner — a floating flanking grant; every grant is one more
##   instance (CR 702.25b), so it is never deduplicated against printed
##   flanking (engine/abilities/flanking.gd).
## Null Rod — an activation ban on every artifact, mana abilities included
##   (CR 605.1a): the planner and every auto-pay leave a banned Mox out.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bubble Matrix":
			c.static_ability(StaticAbility.new(_bubble, "Prevent all damage that would be dealt to creatures."))
		"Chimeric Sphere":
			c.activated(F._ability("{2}", false, Animate.new(2, 1, "construct", [Mtg.Keyword.FLYING], [])))
			c.activated(F._ability("{2}", false, Animate.new(3, 2, "construct", [], [Mtg.Keyword.FLYING])))
		"Xanthic Statue":
			c.activated(F._ability("{5}", false, Animate.new(8, 8, "golem", [Mtg.Keyword.TRAMPLE], [])))
		"Dingus Staff":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _dingus,
				"Whenever a creature dies, this artifact deals 2 damage to that creature's controller.",
				_creature_died).public_aftermath())
		"Mana Web":
			c.triggered(TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _web,
				"Whenever a land an opponent controls is tapped for mana, tap all lands that player controls that could produce any type of mana that land could produce.",
				_opponent_land).capturing(_web_context))
		"Phyrexian Furnace":
			c.activated(F._ability("", true, GraveBottom.new()))
			var exile := F.Action.new(_exile_grave_card, "exile target card from a graveyard",
				TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD, "target card in a graveyard"))
			c.activated(ActivatedAbility.new("{1}", false, [exile, DrawEffect.new(1)],
				"{1}, Sacrifice this artifact: Exile target card from a graveyard. Draw a card.").with_sacrifice_cost())
		"Thran Forge":
			c.activated(F._ability("{2}", false, ForgePump.new(TargetSpec.creature("target nonartifact creature", _nonartifact))))
		"Thran Tome":
			c.activated(F._ability("{5}", true, Tome.new()))
		"Touchstone":
			c.activated(F._ability("", true, TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact you don't control", _artifact).with_source_filter(_not_yours))))
		"Well of Knowledge":
			var well := F._ability("{2}", false, DrawEffect.new(1)).anyone_activated() \
				.during_step(Mtg.Step.DRAW).your_turn_only()
			well.text = "{2}: Draw a card. Any player may activate this ability but only during their draw step."
			c.activated(well)
		"Bösium Strip":
			c.activated(ActivatedAbility.new("{3}", true, [F.Action.new(_strip,
				"until end of turn, you may cast instant and sorcery spells from the top of your graveyard", null, true)],
				"{3}, {T}: Until end of turn, you may cast instant and sorcery spells from the top of your graveyard. If a spell cast this way would be put into a graveyard, exile it instead."))
		"Jabari's Banner":
			c.activated(ActivatedAbility.new("{1}", true, [PumpEffect.new(0, 0, [Mtg.Keyword.FLANKING])],
				"{1}, {T}: Target creature gains flanking until end of turn."))
		"Null Rod":
			c.bans_activations(_null_rod)
		_: return false
	return true


static func _strip(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.grant_graveyard_cast(pid, _instant_or_sorcery, "instant and sorcery spells", true, true, s)

static func _instant_or_sorcery(i: CardInstance) -> bool:
	return i.data.is_type(Mtg.CardType.INSTANT) or i.data.is_type(Mtg.CardType.SORCERY)

## "Activated abilities of artifacts can't be activated" — any player's,
## mana abilities too, read on live types (an animated artifact still is one).
static func _null_rod(_g: MtgGame, _source: CardInstance, _pid: int, inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


# -------------------------------------------------------------- predicates --

static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _nonartifact(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT)
static func _not_yours(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s == null or i.controller_id != s.controller_id


# ------------------------------------------------------------ Bubble Matrix --

## Pass 2c, after every type change: an animated artifact is a creature here.
static func _bubble(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_prevent_all_damage_taken = true


# ------------------------------------------------------------- Dingus Staff --

static func _creature_died(_g: MtgGame, _s: CardInstance, event: GameEvent) -> bool:
	var dead: CardInstance = event.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0

## No source check: a triggered ability resolves even after its source has
## left, dealing damage as the Staff last existed (CR 603.6, 608.2h).
static func _dingus(g: MtgGame, source: CardInstance, event: GameEvent) -> void:
	g.deal_damage(source, TargetRef.player(int(event.data["controller"])), 2)


# ----------------------------------------------------------------- Mana Web --

static func _opponent_land(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") != null and int(event.data.get("controller", source.controller_id)) != source.controller_id

static func _web_context(g: MtgGame, source: CardInstance, event: GameEvent) -> Dictionary:
	var land: CardInstance = event.data["instance"]
	return {"timestamp": source.layer_timestamp, "controller": source.controller_id,
		"player": int(event.data["controller"]), "land": land.id,
		"land_stamp": land.layer_timestamp, "types": g.mana_types_of(land)}

static func _web(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(source)
	var types: Array = context.get("types", [])
	var land := g.find_instance(int(context.get("land", -1)))
	if land != null and land.zone == Mtg.Zone.BATTLEFIELD and land.layer_timestamp == int(context.get("land_stamp", -1)):
		types = g.mana_types_of(land)
	var pid := int(context.get("player", 1 - source.controller_id))
	for i in g.players[pid].battlefield.duplicate():
		if not i.is_land() or i.tapped: continue
		for color in g.mana_types_of(i):
			if types.has(color):
				g.tap_permanent(i)
				break


# -------------------------------------------------------- Phyrexian Furnace --

static func _exile_grave_card(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.exile_from_graveyard(g.find_instance(t.instance_id))

class GraveBottom extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _source: CardInstance, _controller: int, target: TargetRef, _x_value: int = 0) -> void:
		var yard: Array[CardInstance] = g.players[target.player_id].graveyard
		if not yard.is_empty(): g.exile_from_graveyard(yard[0])   # the bottom card
	func describe() -> String:
		return "exile the bottom card of target player's graveyard"


# ---------------------------------------------- Chimeric Sphere / Xanthic Statue --

## "Until end of turn, this artifact becomes an N/N <subtype> artifact
## creature [with/and loses] <keywords>." The keyword half is stamped after
## the animation, so a later activation of either form wins (CR 613.7).
class Animate extends AnimateSelfEffect:
	var gains: Array[int] = []
	var loses: Array[int] = []
	func _init(power: int, toughness: int, subtype: String, gained: Array, lost: Array) -> void:
		super(Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, power, toughness, [subtype])
		for k in gained: gains.append(int(k))
		for k in lost: loses.append(int(k))
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x_value: int = 0) -> void:
		# CR 400.7: an object that left and came back is a new object.
		if source.zone != Mtg.Zone.BATTLEFIELD \
				or source.layer_timestamp != int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
			return
		super.resolve(game, source, controller, target, x_value)
		if not gains.is_empty(): game.continuous.add_until_eot_keywords(source.id, gains)
		if not loses.is_empty(): game.continuous.add_until_eot_loss(source.id, loses)
		game.recalculate()
	func describe() -> String:
		var line := "becomes a %d/%d %s artifact creature until end of turn" % [set_power, set_toughness, add_subtypes[0].capitalize()]
		for k in gains: line += " with " + Mtg.Keyword.keys()[k].capitalize().to_lower()
		for k in loses: line += " and loses " + Mtg.Keyword.keys()[k].capitalize().to_lower()
		return line


# -------------------------------------------------------------- Thran Forge --

class ForgePump extends PumpEffect:
	func _init(spec: TargetSpec) -> void:
		super(1, 0)
		target_spec = spec
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x_value: int = 0) -> void:
		super.resolve(game, source, controller, target, x_value)
		var body := game.find_instance(target.instance_id)
		if body == null or body.zone != Mtg.Zone.BATTLEFIELD: return
		# CR 613.1d (layer 4): a type ADDED until end of turn, bound to this
		# object — forgotten if it leaves (CR 400.7).
		game.continuous.add_floating_static(source, StaticAbility.new(_artifact_until_eot.bind(body.id, body.layer_timestamp),
			"Is an artifact in addition to its other types until end of turn.").changing_types(),
			ContinuousEffects.Duration.END_OF_TURN, -1, false, body.id)
		game.recalculate()
	static func _artifact_until_eot(g: MtgGame, _s: CardInstance, id: int, stamp: int) -> void:
		var body := g.find_instance(id)
		if body != null and body.zone == Mtg.Zone.BATTLEFIELD and body.layer_timestamp == stamp:
			body.cur_types |= Mtg.CardType.ARTIFACT
	func describe() -> String:
		return "target nonartifact creature gets +1/+0 and becomes an artifact in addition to its other types until end of turn"


# --------------------------------------------------------------- Thran Tome --

class Tome extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
		with_ai_role(&"library_selection", {"consume": 3, "value": 6.0})
	func resolve(g: MtgGame, source: CardInstance, controller: int, target: TargetRef, _x_value: int = 0) -> void:
		var library: Array[CardInstance] = g.players[controller].library
		var top: Array[CardInstance] = []
		for n in mini(3, library.size()): top.append(library[library.size() - 1 - n])
		if not top.is_empty():
			var names: Array = []
			for i in top: names.append(i.data.card_name)
			g.reveal_information(-1, "%s — top cards, top first" % source.data.card_name, names)
			g.log_line("%s reveals %s" % [g.players[controller].player_name, ", ".join(PackedStringArray(names))], source)
			# The chooser's own best-first order: the card it most wants to
			# deny (the costliest spell, lands last). Public: all revealed.
			var chooser := target.player_id
			var ordered: Array[CardInstance] = []
			ordered.append_array(top)
			ordered.sort_custom(_deny_first)
			var pick := g.agents[chooser].choose_card(g, chooser, ordered,
				"%s: choose the card %s puts into their graveyard" % [source.data.card_name, g.players[controller].player_name],
				false, true)
			if pick == null or not ordered.has(pick): pick = ordered[0]
			g.move_library_card_to_top(pick)
			g.mill(controller, 1)
		g.draw_cards(controller, 2)
	static func _deny_first(a: CardInstance, b: CardInstance) -> bool:
		if a.data.is_land() != b.data.is_land(): return b.data.is_land()
		return a.data.cost.mana_value() > b.data.cost.mana_value()
	func describe() -> String:
		return "reveal the top three cards of your library; target opponent chooses one to put into your graveyard; draw two cards"
