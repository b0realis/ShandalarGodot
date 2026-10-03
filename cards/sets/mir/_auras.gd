extends RefCounted
## Mirage (_auras, Pack 8). Auras and their enchanted-permanent effects.
##
## Shared by the Visions and Weatherlight Aura modules (vis/_auras.gd,
## wth/_auras.gd), which preload the helpers at the bottom of this file.
##
## Conventions:
## - "Enchant <quality> creature" is the Aura's TargetSpec filter on LIVE
##   characteristics, so the state-based action that re-asks it (CR 303.4d,
##   704.5m — MtgGame.aura_can_enchant) drops the Aura the moment the host
##   stops qualifying: Armor of Thorns falls off a creature Grave Servitude
##   has just made black.
## - Statics read the host through [method host] (present, not phased
##   out). Keyword grants are layer-6 statics (changing_abilities, CR 613.7);
##   colour setters are layer-5 (changing_colors); pumps are layer 7c.
## - A triggered ability names "enchanted creature" as it was when the
##   ability triggered ([method host_context] captures it with its
##   timestamp, [method trigger_host] finds it again only if it is the same
##   object, CR 400.7) — it still resolves after the Aura has left
##   (CR 603.6 / 608.2h).
## - The Mirage flash rider (Ward of Lights, Soar, Grave Servitude,
##   Lightning Reflexes, Armor of Thorns) is CardData.with_flash_rider():
##   the engine judges sorcery timing at cast and schedules the CR 514.3a
##   cleanup sacrifice of the permanent the spell became.
## - Agility's flanking is Flanking.grant (E2): one more INSTANCE, never
##   deduplicated — Agility on a printed knight is two flanking triggers
##   (CR 702.25b).
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Favorable Destiny":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_destiny_pump,
				"Enchanted creature gets +1/+2 as long as it's white."))
			c.static_ability(StaticAbility.new(_destiny_shroud,
				"Enchanted creature has shroud as long as its controller controls another creature.").changing_abilities())
		"Pacifism":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_pacify, "Enchanted creature can't attack or block."))
		"Ritual of Steel":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, slow_draw,
				"When this Aura enters, draw a card at the beginning of the next turn's upkeep.", F._self_enter))
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 2), "Enchanted creature gets +0/+2."))
		"Ward of Lights":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.grants_host_protection_from_chosen("ward_color",
				"Enchanted creature has protection from the chosen color. This effect doesn't remove this Aura.")
			c.as_it_enters(_choose_ward_color)
		"Mind Harness":
			c.enchants(TargetSpec.creature("target red or green creature", _red_or_green).because("color")).steals_control()
			CumulativeUpkeep.attach(c, "{1}")
		"Soar":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 1), "Enchanted creature gets +0/+1."))
			c.static_ability(StaticAbility.new(host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
		"Thirst":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, tap_host,
				"When this Aura enters, tap enchanted creature.", F._self_enter).capturing(host_context))
			c.static_ability(StaticAbility.new(lock_host, "Enchanted creature doesn't untap during its controller's untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{U}"),
				"At the beginning of your upkeep, sacrifice this Aura unless you pay {U}.", F._your_upkeep))
		"Binding Agony":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _agony,
				"Whenever enchanted creature is dealt damage, this Aura deals that much damage to that creature's controller.",
				host_dealt_damage).capturing(_damage_context))
		"Enfeeblement":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(-2, -2), "Enchanted creature gets -2/-2."))
		"Grave Servitude":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, -1), "Enchanted creature gets +3/-1."))
			c.static_ability(StaticAbility.new(_paint_black, "Enchanted creature is black.").changing_colors())
		"Agility":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.static_ability(StaticAbility.new(_agility_flanking, "Enchanted creature has flanking.").changing_abilities())
		"Consuming Ferocity":
			c.enchants(TargetSpec.creature("target non-Wall creature", non_wall).because("walls"))
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 0), "Enchanted creature gets +1/+0."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _ferocity,
				"At the beginning of your upkeep, put a +1/+0 counter on enchanted creature. If that creature has three or more +1/+0 counters on it, it deals damage equal to its power to its controller, then destroy that creature and it can't be regenerated.",
				F._your_upkeep).capturing(host_context))
		"Lightning Reflexes":
			c.enchants(TargetSpec.creature()).with_flash_rider()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 0), "Enchanted creature gets +1/+0."))
			c.static_ability(StaticAbility.new(host_keywords.bind([Mtg.Keyword.FIRST_STRIKE]),
				"Enchanted creature has first strike.").changing_abilities())
		"Armor of Thorns":
			c.enchants(TargetSpec.creature("target nonblack creature", _nonblack).because("color")).with_flash_rider()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 2), "Enchanted creature gets +2/+2."))
		"Decomposition":
			c.enchants(TargetSpec.creature("target black creature", _black).because("color"))
			c.static_ability(StaticAbility.new(grant_trigger.bind(CumulativeUpkeep.ability("", 1)),
				"Enchanted creature has \"Cumulative upkeep—Pay 1 life.\"").changing_abilities() \
				.granting_triggers([Mtg.EventType.UPKEEP_START]))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _decomposed,
				"When enchanted creature dies, its controller loses 2 life.", host_died))
		"Wellspring":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _wellspring_enter,
				"When this Aura enters, gain control of enchanted land until end of turn.",
				F._self_enter).capturing(host_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wellspring_upkeep,
				"At the beginning of your upkeep, untap enchanted land. You gain control of that land until end of turn.",
				F._your_upkeep).capturing(host_context))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## The permanent [param s] enchants, if it is still there and not phased out.
static func host(g: MtgGame, s: CardInstance) -> CardInstance:
	if s == null or s.attached_to == -1: return null
	var i := g.find_instance(s.attached_to)
	return i if g.is_present(i) else null

## The creature an Aura's ACTIVATED ability named: the one it enchanted
## when the ability was activated (MtgGame records it with the cost, so a
## sacrificed Aura still knows), and only if it is still that object.
static func paid_host(g: MtgGame, s: CardInstance) -> CardInstance:
	var i := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
	return i if g.is_present(i) and i.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -2)) else null

## Trigger capture: the source's usual context plus the host as it is now.
static func host_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var i := host(g, s)
	if i != null:
		out.merge({"host": i.id, "host_stamp": i.layer_timestamp, "host_controller": i.controller_id})
	return out

## The host a resolving trigger captured, if it is still the same object.
static func trigger_host(g: MtgGame, s: CardInstance) -> CardInstance:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get("host", -1)))
	return i if g.is_present(i) and i.layer_timestamp == int(ctx.get("host_stamp", -2)) else null

## "You" for a resolving ability: its controller (CR 603.3a / 113.8).
static func pid_of(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id

static func host_keywords(g: MtgGame, s: CardInstance, keywords: Array) -> void:
	var i := host(g, s)
	if i == null: return
	for k in keywords:
		if not i.cur_keywords.has(k): i.cur_keywords.append(k)

## Hand a TRIGGERED ability to the host (Decomposition, Mana Chains): the
## Breath of Dreams shape, layer 6.
static func grant_trigger(g: MtgGame, s: CardInstance, trigger: TriggeredAbility) -> void:
	var i := host(g, s)
	if i != null: i.cur_triggered_abilities.append(trigger)

## Hand an ACTIVATED ability to the host (Fire Whip).
static func grant_ability(g: MtgGame, s: CardInstance, ability: ActivatedAbility) -> void:
	var i := host(g, s)
	if i != null: i.cur_activated_abilities.append(ability)

static func lock_host(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i != null: i.cur_skips_untap = true

static func tap_host(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := trigger_host(g, s)
	if i != null: g.tap_permanent(i)

static func untap_host(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := trigger_host(g, s)
	if i != null: g.untap_permanent(i)

## "When this Aura enters, draw a card at the beginning of the next turn's
## upkeep" (Ritual of Steel, Vampirism) — the Krovikan Fetish slow cantrip.
static func slow_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	DelayedDrawEffect.new().resolve(g, s, pid_of(g, s), null)

## "When enchanted creature dies": the dying card is this Aura's host.
static func host_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and dead.id == s.attached_to

## "Whenever enchanted creature is dealt damage".
static func host_dealt_damage(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and hit.id == s.attached_to and int(e.data.get("amount", 0)) > 0

static func _damage_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := host_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	out["amount"] = int(e.data.get("amount", 0))
	out["victim"] = hit.controller_id
	out["host"] = hit.id
	out["host_stamp"] = hit.layer_timestamp
	return out

static func non_wall(i: CardInstance) -> bool: return not i.has_subtype("wall")
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _red_or_green(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.R | Mtg.ManaColor.G)) != 0
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _black(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) != 0
static func _anything(_i: CardInstance) -> bool: return true


# ------------------------------------------------------- Favorable Destiny --

static func _destiny_pump(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i != null and (i.cur_colors & Mtg.ManaColor.W) != 0:
		i.cur_power += 1
		i.cur_toughness += 2

static func _destiny_shroud(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i == null: return
	for other in g.players[i.controller_id].battlefield:
		if other != i and not other.phased_out and other.is_creature():
			i.cur_shroud = true
			return


# ---------------------------------------------------------------- Pacifism --

static func _pacify(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i == null: return
	i.cur_cant_attack = true
	i.cur_cant_block_filter = _anything


# ---------------------------------------------------------- Ward of Lights --

## The colour is the Aura's controller's to name. Hint, public state only:
## the colour of an opposing spell or ability on the stack that targets the
## creature this Ward enchants (the usual reason to cast it at instant
## speed), else the colour the opponent's battlefield shows most.
static func _choose_ward_color(g: MtgGame, s: CardInstance, pid: int) -> void:
	var best := _threat_color(g, s, pid)
	if best == 0:
		var counts := {}
		for i in g.players[g.opponent_of(pid)].battlefield:
			for color in Mtg.WUBRG:
				if (i.cur_colors & color) != 0: counts[color] = int(counts.get(color, 0)) + 1
		best = Mtg.ManaColor.B
		for color in Mtg.WUBRG:
			if int(counts.get(color, 0)) > int(counts.get(best, 0)): best = color
	var picked := g.agents[pid].choose_color(g, pid, "%s: choose a color" % s.data.card_name, best)
	g._rec(s, &"memory")
	s.memory["ward_color"] = picked if Mtg.WUBRG.has(picked) else best

static func _threat_color(g: MtgGame, s: CardInstance, pid: int) -> int:
	if s.attached_to == -1: return 0
	for n in range(g.stack.size() - 1, -1, -1):
		var item: StackItem = g.stack[n]
		if item.controller == pid or item.card == null: continue
		for t in item.targets:
			if t != null and not t.is_player and t.instance_id == s.attached_to:
				for color in Mtg.WUBRG:
					if (item.card.cur_colors & color) != 0: return color
	return 0


# ---------------------------------------------------------- Grave Servitude --

## Layer 5: "is black" REPLACES its colours (CR 105.3).
static func _paint_black(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i != null: i.cur_colors = Mtg.ManaColor.B


# ------------------------------------------------------------ Binding Agony --

## The damage comes from the Aura — as it last existed if the dealt damage
## killed the creature and the Aura went to the graveyard with it — and
## hits the player who controlled the creature when it was dealt damage.
static func _agony(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var amount := int(ctx.get("amount", 0))
	if amount > 0:
		g.deal_damage(s, TargetRef.player(int(ctx.get("victim", s.controller_id))), amount)


# ------------------------------------------------------------------ Agility --

static func _agility_flanking(g: MtgGame, s: CardInstance) -> void:
	var i := host(g, s)
	if i != null: Flanking.grant(i)


# ------------------------------------------------------- Consuming Ferocity --

static func _ferocity(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := trigger_host(g, s)
	if i == null: return
	g.add_counters(i, "+1/+0")
	if not g.is_present(i) or int(i.counters.get("+1/+0", 0)) < 3: return
	g.deal_damage(i, TargetRef.player(i.controller_id), maxi(i.cur_power, 0))
	g.destroy(i, false)


# ------------------------------------------------------------ Decomposition --

static func _decomposed(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var dead: CardInstance = e.data.get("instance")
	g.adjust_life(int(e.data.get("controller", dead.controller_id)), -2)


# --------------------------------------------------------------- Wellspring --

static func _wellspring_enter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := trigger_host(g, s)
	if i != null: g.gain_control_until_eot(i, pid_of(g, s))

static func _wellspring_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := trigger_host(g, s)
	if i == null: return
	g.untap_permanent(i)
	g.gain_control_until_eot(i, pid_of(g, s))


# ------------------------------------------------------------------ effects --
#
# An Aura's ACTIVATED ability names "enchanted creature": the one it
# enchanted when the ability was activated (MtgGame records it with the
# cost, so an Aura sacrificed as the cost still knows — CR 608.2h), and only
# if it is still that object (CR 400.7). Inner classes do not reach the
# outer statics, so each inlines that lookup.

## "Enchanted creature gets +P/+T until end of turn". Declares the
## `pump_host` AI role (the Firebreathing convention, 2026-09-30) so the
## AI's pump paths find the breath on the body that wears it.
class HostPump extends EffectBase:
	var power: int
	var toughness: int
	func _init(p: int, t: int) -> void:
		power = p
		toughness = t
		ai_helpful = true
		with_ai_role(&"pump_host", {"power": p, "toughness": t})
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if not g.is_present(i) or i.layer_timestamp != int(g.cost_paid("_source_attached_timestamp", -2)):
			return
		g.continuous.add_until_eot_pump(i.id, power, toughness, [])
		g.log_line("%s gives %s %+d/%+d until end of turn" % [source.data.card_name, i.data.card_name, power, toughness], source)
		g.recalculate()
	func describe() -> String:
		return "enchanted creature gets %+d/%+d until end of turn" % [power, toughness]

## "Return enchanted creature to its owner's hand" — a typed bounce.
class HostBounce extends ReturnToHandEffect:
	func _init() -> void:
		super()
		target_spec = null
	func resolve(g: MtgGame, _source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if g.is_present(i) and i.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -2)):
			g.return_to_hand(i)
	func describe() -> String:
		return "return enchanted creature to its owner's hand"

## "Regenerate enchanted creature" — a typed regeneration shield.
class HostRegenerate extends RegenerateEffect:
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(int(g.cost_paid("_source_attached_to", -1)))
		if not g.is_present(i) or i.layer_timestamp != int(g.cost_paid("_source_attached_timestamp", -2)):
			return
		g._rec(i, &"regeneration_shields")
		i.regeneration_shields += 1
		g.log_line("%s gives %s a regeneration shield (%d)" % [source.data.card_name, i.data.card_name, i.regeneration_shields], source)
	func describe() -> String:
		return "regenerate enchanted creature"
