extends RefCounted
## Exodus (_auras, Pack 9). Auras and their enchanted-permanent effects.
##
## The shared helpers live in cards/sets/mir/_auras.gd (A): statics read the
## host through A.host (present, not phased out); keyword grants are layer-6
## statics (changing_abilities, CR 613.7); a triggered ability names
## "enchanted creature" as it was when it triggered (A.host_context /
## A.trigger_host, CR 400.7) and still resolves after the Aura has left
## (CR 603.6, 608.2h). "You" is the Aura's controller when the ability
## triggered (the dispatcher captures it, F._source_context).
##
## Dizzying Gaze's "Enchant creature you control" is the Aura's TargetSpec
## with a source filter, so the Aura falls off on a control change
## (CR 303.4d, MtgGame.aura_can_enchant). Its "{R}: Enchanted creature deals
## 1 damage" is the AURA's ability — the creature deals the damage, but it
## is not tapped and summoning sickness does not apply (CR 302.6 names only
## {T} abilities of the creature itself).
##
## tests/cards/test_pack_9_B12_auras.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bequeathal":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _bequeathal,
				"When enchanted creature dies, you draw two cards.", A.host_died))
		"Cunning":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, 3), "Enchanted creature gets +3/+3."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _cunning,
				"When enchanted creature attacks or blocks, sacrifice this Aura at the beginning of the next cleanup step.",
				_host_attacks))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _cunning,
				"When enchanted creature attacks or blocks, sacrifice this Aura at the beginning of the next cleanup step.",
				_host_blocks))
		"Curiosity":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _curiosity,
				"Whenever enchanted creature deals damage to an opponent, you may draw a card.", _host_hit_opponent))
		"Cursed Flesh":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(-1, -1), "Enchanted creature gets -1/-1."))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FEAR]),
				"Enchanted creature has fear.").changing_abilities())
		"Dizzying Gaze":
			c.enchants(TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller"))
			c.activated(ActivatedAbility.new("{R}", false, [GazeDamage.new()],
				"{R}: Enchanted creature deals 1 damage to target creature with flying."))
		"Maniacal Rage":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
			c.static_ability(StaticAbility.new(_cant_block, "Enchanted creature can't block."))
		"Paroxysm":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _paroxysm,
				"At the beginning of the upkeep of enchanted creature's controller, that player reveals the top card of their library. If that card is a land card, destroy that creature. Otherwise, it gets +3/+3 until end of turn.",
				_host_controllers_upkeep).capturing(A.host_context))
		"Predatory Hunger":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _hunger,
				"Whenever an opponent casts a creature spell, put a +1/+1 counter on enchanted creature.",
				_opponent_creature_spell).capturing(A.host_context))
		"Robe of Mirrors":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_shroud_host, "Enchanted creature has shroud.").changing_abilities())
		"Shackles":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.lock_host, "Enchanted creature doesn't untap during its controller's untap step."))
			c.activated(ActivatedAbility.new("{W}", false,
				[F.Action.new(_shackles_home, "return this Aura to its owner's hand", null, false) \
					.with_ai_role(&"return_self_to_hand")],
				"{W}: Return this Aura to its owner's hand."))
		_: return false
	return true


static func _anything(_i: CardInstance) -> bool: return true
static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id == g.controller_acting_for(s)
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)

## "You": the Aura's controller as the ability triggered.
static func _you(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))


# -------------------------------------------------------------- Bequeathal --

static func _bequeathal(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(_you(g, s), 2)


# ----------------------------------------------------------------- Cunning --

static func _host_attacks(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if s.attached_to == -1: return false
	for i in e.data.get("attackers", []):
		if i != null and (i as CardInstance).id == s.attached_to: return true
	return false

static func _host_blocks(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and s.attached_to != -1 and i.id == s.attached_to

## The sacrifice is a DELAYED trigger (CR 603.7) at the beginning of the
## next cleanup step (CR 514.3a), bound to this Aura as the object it is
## now: one that left and came back is a new object and stays (CR 400.7).
## "Sacrifice this Aura" — only the player who controls it then can, and
## that is the delayed trigger's controller (CR 603.7d, 701.17a).
static func _cunning(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := _you(g, s)
	g.schedule_cleanup_action(_cunning_sacrifice.bind(s.id, s.layer_timestamp, pid), s, pid,
		"Cunning: sacrifice this Aura.")

static func _cunning_sacrifice(g: MtgGame, id: int, stamp: int, pid: int) -> void:
	var aura := g.find_instance(id)
	if g.is_present(aura) and aura.layer_timestamp == stamp and aura.controller_id == pid:
		g.sacrifice_permanent(aura)


# --------------------------------------------------------------- Curiosity --

## "Deals damage to an opponent" — an opponent of the Aura's controller,
## and only damage actually dealt (a prevented packet deals 0).
static func _host_hit_opponent(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var src: CardInstance = e.data.get("source")
	if src == null or s.attached_to == -1 or src.id != s.attached_to: return false
	if not e.data.has("to_player") or int(e.data.get("amount", 0)) <= 0: return false
	return int(e.data.get("to_player", -1)) != s.controller_id

static func _curiosity(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Curiosity: draw a card?", true):
		g.draw_cards(pid, 1)


# ----------------------------------------------------------- Dizzying Gaze --

## "Enchanted creature deals 1 damage to target creature with flying." The
## creature the Aura enchanted when the ability was activated deals it — as
## it last existed if it has left since (CR 608.2h).
class GazeDamage extends DamageEffect:
	func _init() -> void:
		super(1)
		target_creature("target creature with flying", _flier)
	static func _flier(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var creature := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if creature == null or t == null: return
		g.deal_damage(creature, t, amount)
	func describe() -> String:
		return "enchanted creature deals 1 damage to target creature with flying"


# ----------------------------------------------------------- Maniacal Rage --

static func _cant_block(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_cant_block_filter = _anything


# ---------------------------------------------------------------- Paroxysm --

static func _host_controllers_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and int(e.data.get("player", -1)) == i.controller_id

## "That player reveals the top card of their library" — the enchanted
## creature's controller, whose upkeep it is. An empty library reveals
## nothing, so the land branch cannot happen and "otherwise" does.
static func _paroxysm(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", g.active_player))
	var library := g.players[who].library
	var top: CardInstance = null if library.is_empty() else library.back()
	if top != null:
		g.reveal_information(-1, "Paroxysm reveals", [top.data.card_name])
		g.log_line("%s reveals %s (Paroxysm)" % [g.players[who].player_name, top.data.card_name])
	var i := A.trigger_host(g, s)
	if i == null: return
	if top != null and top.data.is_land():
		g.destroy(i)
		return
	g.continuous.add_until_eot_pump(i.id, 3, 3)
	g.recalculate()


# -------------------------------------------------------- Predatory Hunger --

static func _opponent_creature_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return spell != null and spell.data.is_creature() and s.attached_to != -1 \
		and int(e.data.get("controller", -1)) != s.controller_id

static func _hunger(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null: g.add_counters(i, "+1/+1")


# --------------------------------------------------------- Robe of Mirrors --

static func _shroud_host(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_shroud = true


# ---------------------------------------------------------------- Shackles --

## "Return this Aura to its owner's hand" — only the object that activated
## it (CR 400.7); a phased-out one is treated as though it doesn't exist.
static func _shackles_home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s): g.return_to_hand(s)
