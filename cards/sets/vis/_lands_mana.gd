extends RefCounted
## Visions (_lands_mana, Pack 8). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## Mana sources are declared in shapes the one mana planner
## (engine/mana_planner.gd) reads without callbacks. The bounce lands' two
## mana come from ONE tap ("{T}: Add {C}{W}"), which the planner treats as
## one atomic multi-output row. Squandered Resources' "Sacrifice a land" is
## an object cost ([member ManaAbility.object_costs]): the planner never
## takes it on by itself — eating a land is the player's explicit choice.
const F := preload("res://cards/sets/fem/_rules.gd")

## bounce land -> [land type it returns, its colour, the type's name]
const KAROOS := {
	"Coral Atoll": ["island", Mtg.ManaColor.U, "Island"],
	"Dormant Volcano": ["mountain", Mtg.ManaColor.R, "Mountain"],
	"Everglades": ["swamp", Mtg.ManaColor.B, "Swamp"],
	"Jungle Basin": ["forest", Mtg.ManaColor.G, "Forest"],
	"Karoo": ["plains", Mtg.ManaColor.W, "Plains"],
}

static func configure(c: CardData) -> bool:
	var n := c.card_name
	if KAROOS.has(n):
		var row: Array = KAROOS[n]
		c.with_enters_tapped()
		c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
			_bounce_or_sacrifice.bind(row[0], row[2]),
			"Sacrifice this land unless you return an untapped %s you control to its owner's hand." % row[2],
			F._self_enter))
		c.mana(ManaAbility.new(Mtg.ManaColor.C).and_also(row[1]))
		return true
	match n:
		"Squandered Resources":
			# No {T}: one activation per land fed to it. The type is chosen
			# from what the sacrificed land could produce, read before it
			# leaves (MtgGame.tap_for_mana's borrow_paid_land_type), whether
			# or not that land was tapped.
			var ability := ManaAbility.new(Mtg.ManaColor.C).without_tap()
			ability.object_costs = [{"operation": "sacrifice", "filter": _land, "desc": "a land"}]
			ability.borrow_paid_land_type = true
			c.mana(ability)
		"Undiscovered Paradise":
			# The return is part of the mana ability's effect: a delayed
			# action for the activator's next untap step that happens (a
			# skipped one does not count), about THIS object only (CR 400.7).
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color).with_side_effect(_paradise))
		"Sisay's Ring":
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 2))
		"Griffin Canyon":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("", true, [GriffinUntap.new()],
				"{T}: Untap target Griffin. If it's a creature, it gets +1/+1 until end of turn."))
		"Quicksand":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			var sink := PumpEffect.new(-1, -2)
			sink.target_spec = TargetSpec.creature("target attacking creature without flying", _no_flying) \
				.with_game_filter(_attacking)
			c.activated(ActivatedAbility.new("", true, [sink],
				"{T}, Sacrifice this land: Target attacking creature without flying gets -1/-2 until end of turn.").with_sacrifice_cost())
		_: return false
	return true

static func _land(i: CardInstance) -> bool: return i.is_land()
static func _no_flying(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)

static func _paradise(g: MtgGame, s: CardInstance, pid: int) -> void:
	g.schedule_untap_step_action(pid, _paradise_returns.bind(s.id, s.layer_timestamp), s)

static func _paradise_returns(g: MtgGame, id: int, stamp: int) -> void:
	var land := g.find_instance(id)
	if land != null and land.zone == Mtg.Zone.BATTLEFIELD and land.layer_timestamp == stamp:
		g.return_to_hand(land)

## "When this land enters, sacrifice it unless you return an untapped
## <type> you control to its owner's hand." Resolves only for the object
## that triggered (CR 400.7). The return is optional (CR 118.12 — "unless"
## offers the action): declining, or having no untapped land of the type
## when it resolves, sacrifices the land.
static func _bounce_or_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent, kind: String, label: String) -> void:
	if not F._same_trigger_source(g, s):
		return
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.has_subtype(kind) and not i.tapped:
			choices.append(i)
	var pick: CardInstance = null
	if not choices.is_empty():
		pick = g.agents[pid].choose_card(g, pid, choices,
			"Return an untapped %s you control to its owner's hand, or sacrifice %s" % [label, s.data.card_name], true)
	if pick != null and choices.has(pick):
		g.return_to_hand(pick)
	elif s.controller_id == pid:
		g.sacrifice_permanent(s)

## "Untap target Griffin. If it's a creature, it gets +1/+1 until end of
## turn." One target; the creature check is made as the ability resolves.
class GriffinUntap extends UntapEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Griffin", _griffin))
		ai_helpful = true
	static func _griffin(i: CardInstance) -> bool: return i.has_subtype("griffin")
	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x_value := 0) -> void:
		super(game, source, controller, target, x_value)
		var inst := game.find_instance(target.instance_id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.is_creature():
			PumpEffect.new(1, 1).resolve(game, source, controller, target)
	func describe() -> String:
		return "untap target Griffin; if it's a creature, it gets +1/+1 until end of turn"
