extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dreams of the Dead":
			c.activated(F._ability("{1}{U}", false, F.Action.new(_dreams, "return a white or black creature; it gains cumulative upkeep {2} and is exiled if it leaves", TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD, "target white or black creature in your graveyard", _white_black), true)))
		"Dance of the Dead":
			c.enchants(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD, "target creature card in a graveyard", _creature))
			c.aura_graveyard_entry = true
			c.as_it_enters(_dance_enter)
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _dance_raise, "Return the enchanted card tapped under your control and attach this Aura to it.", F._self_enter))
			c.static_ability(StaticAbility.new(_dance_static, "Enchanted creature gets +1/+1 and doesn't untap during its controller's untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _dance_upkeep, "Enchanted creature's controller may pay {1}{B} to untap it.", A._host_upkeep).capturing(A._host_context))
		_: return false
	return true

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _white_black(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.W | Mtg.ManaColor.B)) != 0
static func _dreams(g: MtgGame, s: CardInstance, pid: int, target: TargetRef, _x: int) -> void:
	var i := g.find_instance(target.instance_id)
	if i == null: return
	g.reanimate(i, pid)
	if i.zone != Mtg.Zone.BATTLEFIELD: return
	g.continuous.add_floating_static(s, StaticAbility.new(_dreams_grant.bind(i.id), "Cumulative upkeep {2}; exile instead of leaving the battlefield.").changing_abilities(), ContinuousEffects.Duration.INDEFINITE, -1, false, i.id)
	g.recalculate()
static func _dreams_grant(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
	i.cur_exile_on_leaving = true
	i.cur_triggered_abilities.append(CumulativeUpkeep.ability("{2}"))
static func _dance_enter(g: MtgGame, s: CardInstance, _pid: int) -> void:
	var i := g.find_instance(s.attached_to)
	g._rec(s, &"memory")
	s.memory["grave_entry"] = i.graveyard_entry if i != null else -1
static func _dance_raise(g: MtgGame, s: CardInstance, _event: GameEvent) -> void:
	# "if it's on the battlefield" fails while it is phased out (CR 603.4, 702.26b).
	if not F._same_trigger_source(g, s) or not g.is_present(s): return
	var i := g.find_instance(s.attached_to)
	if i == null or i.zone != Mtg.Zone.GRAVEYARD or i.graveyard_entry != int(s.memory.get("grave_entry", -1)): return
	var pid := int(g.trigger_context(s).controller)
	g._rec(s, &"memory")
	s.memory["raised"] = true
	s.memory["raised_id"] = i.id
	# The attached object's new timestamp is assigned at entry. No SBA
	# occurs mid-resolution; the ETB sees the creature already tapped.
	g.reanimate(i, pid, true)
	if i.zone != Mtg.Zone.BATTLEFIELD: return
	s.memory["raised_stamp"] = i.layer_timestamp
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _dance_sacrifice.bind(i.id, i.layer_timestamp), "The returned creature's controller sacrifices it.", load("res://cards/sets/ice/_control.gd")._released.bind(s.id, s.layer_timestamp)), pid, s)
	g.recalculate()
static func _dance_static(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null or not bool(s.memory.get("raised", false)): return
	if s.memory.has("raised_stamp") and i.layer_timestamp != int(s.memory.raised_stamp): return
	i.cur_power += 1
	i.cur_toughness += 1
	i.cur_skips_untap = true
static func _dance_sacrifice(g: MtgGame, _s: CardInstance, _event: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.sacrifice_permanent(i)
static func _dance_upkeep(g: MtgGame, s: CardInstance, _event: GameEvent) -> void:
	var i := A._trigger_host(g, s)
	if i == null: return
	var pid := i.controller_id
	if i.tapped and EffectBase.unless_paid(g, pid, ManaCost.parse("{1}{B}"), "Dance of the Dead: pay {1}{B} to untap " + i.data.card_name + "?"):
		g.untap_permanent(i)
