extends RefCounted
## Weatherlight (_auras, Pack 8). Auras and their enchanted-permanent effects.
##
## The shared helpers and host effects live in cards/sets/mir/_auras.gd
## (A). Every "Sacrifice this Aura: ... enchanted creature ..." ability
## resolves on the creature the Aura enchanted when it was activated (the
## cost record keeps it — CR 608.2h), and only if that creature is still
## the same object (CR 400.7).
##
## Kithkin Armor — SourceShieldEffect.prevent_to_enchanted() (E5): the
##   source is named as the ability resolves (CR 609.7a) and one damage
##   event uses the shield up.
## Abduction — Control Magic's steal (CardData.steals_control) plus a dies
##   trigger that returns the card from its owner's graveyard under its
##   owner's control (the same object only: graveyard entry captured).
## Apathy — the "may discard at random" is the enchanted creature's
##   CONTROLLER's choice, asked as the trigger resolves.
## Betrothed of Fire — "Sacrifice enchanted creature" is an object cost
##   (engine/additional_object_costs.gd) whose source_filter names the host;
##   only a host its controller controls can be sacrificed (CR 701.17a).
## Fire Whip — the granted "{T}: This creature deals 1 damage to any
##   target." is the HOST's ability (its controller activates it, the
##   creature deals the damage, summoning sickness applies — CR 302.6).
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Empyrial Armor":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_empyrial, "Enchanted creature gets +1/+1 for each card in your hand."))
		"Kithkin Armor":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_kithkin_evasion,
				"Enchanted creature can't be blocked by creatures with power 3 or greater."))
			c.activated(ActivatedAbility.new("", false, [SourceShieldEffect.prevent_to_enchanted()],
				"Sacrifice this Aura: The next time a source of your choice would deal damage to enchanted creature this turn, prevent that damage.") \
				.with_sacrifice_cost())
		"Abduction":
			c.enchants(TargetSpec.creature()).steals_control()
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, A.untap_host,
				"When this Aura enters, untap enchanted creature.", F._self_enter).capturing(A.host_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _abduction_return,
				"When enchanted creature dies, return that card to the battlefield under its owner's control.",
				A.host_died).capturing(_dead_context))
		"Apathy":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.lock_host, "Enchanted creature doesn't untap during its controller's untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _apathy,
				"At the beginning of the upkeep of enchanted creature's controller, that player may discard a card at random. If the player does, untap that creature.",
				_host_controllers_upkeep).capturing(A.host_context))
		"Mana Chains":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.grant_trigger.bind(CumulativeUpkeep.ability("{1}")),
				"Enchanted creature has \"Cumulative upkeep {1}.\"").changing_abilities() \
				.granting_triggers([Mtg.EventType.UPKEEP_START]))
		"Phantom Wings":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			c.activated(ActivatedAbility.new("", false, [A.HostBounce.new()],
				"Sacrifice this Aura: Return enchanted creature to its owner's hand.").with_sacrifice_cost())
		"Coils of the Medusa":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, -1), "Enchanted creature gets +1/-1."))
			c.activated(ActivatedAbility.new("", false, [DestroyHostBlockers.new()],
				"Sacrifice this Aura: Destroy all non-Wall creatures blocking enchanted creature.").with_sacrifice_cost())
		"Betrothed of Fire":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("", false, [A.HostPump.new(2, 0)],
				"Sacrifice an untapped creature: Enchanted creature gets +2/+0 until end of turn.") \
				.with_sacrifice_of("untapped creature", _untapped_creature))
			var host_cost := OC.sacrificing("enchanted creature", _creature)
			host_cost["source_filter"] = _is_host
			c.activated(ActivatedAbility.new("", false, [MassPumpEffect.new(2, 0, "creatures you control").yours_only()],
				"Sacrifice enchanted creature: Creatures you control get +2/+0 until end of turn.") \
				.with_object_cost(host_cost))
		"Fire Whip":
			c.enchants(TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller"))
			c.static_ability(StaticAbility.new(A.grant_ability.bind(ActivatedAbility.new("", true,
				[DamageEffect.new(1).any_target()], "{T}: This creature deals 1 damage to any target.")),
				"Enchanted creature has \"{T}: This creature deals 1 damage to any target.\"").changing_abilities())
			c.activated(ActivatedAbility.new("", false, [DamageEffect.new(1).any_target()],
				"Sacrifice this Aura: It deals 1 damage to any target.").with_sacrifice_cost())
		"Briar Shield":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.activated(ActivatedAbility.new("", false, [A.HostPump.new(3, 3)],
				"Sacrifice this Aura: Enchanted creature gets +3/+3 until end of turn.").with_sacrifice_cost())
		"Nature's Kiss":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{1}", false, [A.HostPump.new(1, 1)],
				"{1}, Exile the top card of your graveyard: Enchanted creature gets +1/+1 until end of turn.") \
				.with_object_cost(OC.exiling_top("card")))
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _untapped_creature(i: CardInstance) -> bool: return i.is_creature() and not i.tapped
static func _is_host(_g: MtgGame, card: CardInstance, source: CardInstance) -> bool:
	return source != null and source.attached_to == card.id
static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id == g.controller_acting_for(s)


# ------------------------------------------------------------ Empyrial Armor --

static func _empyrial(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	var n := g.players[s.controller_id].hand.size()
	i.cur_power += n
	i.cur_toughness += n


# -------------------------------------------------------------- Kithkin Armor --

static func _kithkin_evasion(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	if i.cur_cant_be_blocked_by_power_ge <= 0 or i.cur_cant_be_blocked_by_power_ge > 3:
		i.cur_cant_be_blocked_by_power_ge = 3


# ------------------------------------------------------------------ Abduction --

static func _dead_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var dead: CardInstance = e.data.get("instance")
	out["id"] = dead.id
	out["entry"] = int(e.data.get("graveyard_entry", dead.graveyard_entry))
	return out

static func _abduction_return(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var card := g.find_instance(int(ctx.get("id", -1)))
	if card != null and card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(ctx.get("entry", -1)):
		g.reanimate(card, card.owner_id)


# --------------------------------------------------------------------- Apathy --

static func _host_controllers_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and i.controller_id == int(e.data.get("player", -1))

## The creature's controller decides; the hint (public state and their own
## hand only): untap a tapped creature worth more than a random card.
static func _apathy(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i == null: return
	var pid := i.controller_id
	var hand := g.players[pid].hand
	if hand.is_empty(): return
	var hint := i.tapped and (i.cur_power >= 2 or i.data.cost.mana_value() >= 3)
	if not g.agents[pid].choose_yes_no(g, pid,
			"%s: discard a card at random to untap %s?" % [s.data.card_name, i.data.card_name], hint):
		return
	var before := hand.size()
	g.discard_random(pid, 1)
	if g.players[pid].hand.size() < before and g.is_present(i):
		g.untap_permanent(i)


# -------------------------------------------------------- Coils of the Medusa --

## "Destroy all non-Wall creatures blocking enchanted creature" — the
## creature the Aura enchanted when it was sacrificed; its blockers as the
## ability resolves.
class DestroyHostBlockers extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, _source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if not g.is_present(i) or i.layer_timestamp != int(g.cost_paid("_source_attached_timestamp", -2)):
			return
		var doomed: Array[CardInstance] = []
		for id in g.combat.blockers_of(i.id):
			var b := g.find_instance(int(id))
			if g.is_present(b) and b.is_creature() and not b.has_subtype("wall"):
				doomed.append(b)
		g.begin_simultaneous()
		for b in doomed: g.destroy(b)
		g.end_simultaneous()
	func describe() -> String:
		return "destroy all non-Wall creatures blocking enchanted creature"
