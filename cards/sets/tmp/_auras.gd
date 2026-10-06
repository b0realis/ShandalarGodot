extends RefCounted
## Tempest (_auras, Pack 9). Auras and their enchanted-permanent effects.
##
## The shared helpers and host effects live in cards/sets/mir/_auras.gd
## (A): host lookups, trigger host capture (a trigger names "enchanted
## creature" as it was when the ability triggered, and finds it again only
## if it is the same object — CR 400.7, 603.6), HostPump (resolves on the
## creature the Aura enchanted when its ability was activated).
##
## - "{c}: Return this Aura to its owner's hand" (Crown of Flames,
##   Flickering Ward, Shimmering Wings) is [AuraReturn]: it returns the very
##   object that was activated, if it is still on the battlefield, and
##   declares the `self_bounce` AI role (the Viscerid Armor reading).
## - Flickering Ward is Ward of Lights without the flash rider: the colour
##   is chosen as it enters (CR 614.12, A._choose_ward_color) and the grant
##   never removes this Aura (CardData.grants_host_protection_from_chosen,
##   CR 702.16d). Another source's protection still does.
## - Endless Scream: "enters with X scream counters" reads the X the cast
##   recorded (Soul Echo's shape); the pump counts the counters on the AURA.
## - Spinal Graft: BECAME_TARGET on the host (announced once per distinct
##   target per stack object); the creature it enchanted when the ability
##   triggered is destroyed without regeneration.
## - Sadistic Glee: every creature's death, its own host's included — that
##   one finds no host to grow.
## - Steal Enchantment: Control Magic's steal (CardData.steals_control) on
##   an enchantment; an Aura it steals stays on what it enchants.
## - Tahngarth's Rage: "attacking" is the combat state (CR 506.4), read on
##   every recalculation.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Crown of Flames":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{R}", false, [A.HostPump.new(1, 0)],
				"{R}: Enchanted creature gets +1/+0 until end of turn."))
			c.activated(ActivatedAbility.new("{R}", false, [AuraReturn.new()],
				"{R}: Return this Aura to its owner's hand."))
		"Endless Scream":
			c.enchants(TargetSpec.creature())
			c.as_it_enters(_scream_counters)
			c.static_ability(StaticAbility.new(_scream_pump,
				"Enchanted creature gets +1/+0 for each scream counter on this Aura."))
		"Flickering Ward":
			c.enchants(TargetSpec.creature())
			c.grants_host_protection_from_chosen("ward_color",
				"Enchanted creature has protection from the chosen color. This effect doesn't remove this Aura.")
			c.as_it_enters(A._choose_ward_color)
			c.activated(ActivatedAbility.new("{W}", false, [AuraReturn.new()],
				"{W}: Return this Aura to its owner's hand."))
		"Frog Tongue":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _draw_one,
				"When this Aura enters, draw a card.", F._self_enter))
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.REACH]),
				"Enchanted creature has reach.").changing_abilities())
		"Hero's Resolve":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 5), "Enchanted creature gets +1/+5."))
		"Sadistic Glee":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _glee,
				"Whenever a creature dies, put a +1/+1 counter on enchanted creature.",
				_a_creature_died).capturing(A.host_context).public_aftermath())
		"Shimmering Wings":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			c.activated(ActivatedAbility.new("{U}", false, [AuraReturn.new()],
				"{U}: Return this Aura to its owner's hand."))
		"Spinal Graft":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, 3), "Enchanted creature gets +3/+3."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _graft,
				"When enchanted creature becomes the target of a spell or ability, destroy that creature. It can't be regenerated.",
				_host_targeted).capturing(A.host_context))
		"Steal Enchantment":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _enchantment)).steals_control()
		"Tahngarth's Rage":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_rage,
				"Enchanted creature gets +3/+0 as long as it's attacking. Otherwise, it gets -2/-1."))
		_: return false
	return true


static func _enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)

static func _draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(A.pid_of(g, s), 1)


# ------------------------------------------------------------ Endless Scream --

## "This Aura enters with X scream counters on it" — a replacement
## (CR 614.1c) reading the X the cast recorded (mir/_misc.gd, Soul Echo).
static func _scream_counters(g: MtgGame, inst: CardInstance, _pid: int) -> void:
	var x := int(inst.memory.get("x_value", 0))
	if x > 0:
		g.add_counters(inst, "scream", x)

static func _scream_pump(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null:
		i.cur_power += int(s.counters.get("scream", 0))


# ------------------------------------------------------------- Sadistic Glee --

static func _a_creature_died(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0

static func _glee(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null:
		g.add_counters(i, "+1/+1")


# -------------------------------------------------------------- Spinal Graft --

static func _host_targeted(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and s.attached_to != -1 and i.id == s.attached_to

static func _graft(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var i := A.trigger_host(g, s)
	if i != null:
		g.destroy(i, false)


# ---------------------------------------------------------- Tahngarth's Rage --

static func _rage(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i == null: return
	if g.combat.attackers.has(i.id):
		i.cur_power += 3
	else:
		i.cur_power -= 2
		i.cur_toughness -= 1


# ------------------------------------------------------------------ effects --

## "Return this Aura to its owner's hand" — the object that was activated,
## only while it is still that object on the battlefield (CR 400.7) and
## phased in (CR 702.26b). Declares the `self_bounce` AI role: the AI's
## reading answers a removal spell aimed at the Aura by taking it home
## (engine/ai/alliances_tactics.gd).
class AuraReturn extends ReturnToHandEffect:
	func _init() -> void:
		super()
		target_spec = null
		ai_helpful = true
		with_ai_role(&"self_bounce")
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if g.is_present(source) and source.layer_timestamp == int(g.cost_paid("_source_timestamp", source.layer_timestamp)):
			g.return_to_hand(source)
	func describe() -> String:
		return "return this Aura to its owner's hand"
