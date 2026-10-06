extends RefCounted
## Exodus (_artifacts, Pack 9). Noncreature artifacts and their activated or static abilities.
##
## Coat of Arms and Spellbook are ordinary statics, so the 1997 "tapped
## artifacts stop" rule (fifth preset, cur_statics_suspended) switches them
## off with no card code. Every self-referring activated ability acts only
## on the object that paid for it (CR 400.7 — F._same_activation_source).
## tests/cards/test_pack_9_B12_artifacts.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const OC := preload("res://engine/additional_object_costs.gd")
const TYPES := preload("res://engine/core/creature_types.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Coat of Arms":
			c.static_ability(StaticAbility.new(_coat_of_arms,
				"Each creature gets +1/+1 for each other creature on the battlefield that shares at least one creature type with it."))
		"Erratic Portal":
			c.activated(ActivatedAbility.new("{1}", true, [PortalBounce.new()],
				"{1}, {T}: Return target creature to its owner's hand unless its controller pays {1}."))
		"Medicine Bag":
			c.activated(ActivatedAbility.new("{1}", true, [RegenerateEffect.new().target_creature()],
				"{1}, {T}, Discard a card: Regenerate target creature.").with_discard_cost(1))
		"Mindless Automaton":
			c.with_enters_counters("+1/+1", 2)
			c.activated(ActivatedAbility.new("{1}", false, [SelfCounter.new("+1/+1")],
				"{1}, Discard a card: Put a +1/+1 counter on this creature.").with_discard_cost(1))
			c.activated(ActivatedAbility.new("", false, [DrawEffect.new(1)],
				"Remove two +1/+1 counters from this creature: Draw a card.").with_counter_cost("+1/+1", 2))
		"Null Brooch":
			c.activated(ActivatedAbility.new("{2}", true, [CounterEffect.new("target noncreature spell", _noncreature)],
				"{2}, {T}, Discard your hand: Counter target noncreature spell.").with_object_cost(OC.discard_hand()))
		"Skyshaper":
			c.activated(ActivatedAbility.new("", false,
				[MassPumpEffect.new(0, 0, "creatures you control", [Mtg.Keyword.FLYING]).yours_only()],
				"Sacrifice this artifact: Creatures you control gain flying until end of turn.").with_sacrifice_cost())
		"Spellbook":
			c.static_ability(StaticAbility.new(_no_maximum_hand_size, "You have no maximum hand size."))
		"Thopter Squadron":
			c.with_enters_counters("+1/+1", 3)
			c.activated(ActivatedAbility.new("{1}", false, [ThopterToken.new()],
				"{1}, Remove a +1/+1 counter from this creature: Create a 1/1 colorless Thopter artifact creature token with flying. Activate only as a sorcery.") \
				.with_counter_cost("+1/+1", 1).only_if(MA.sorcery_speed))
			c.activated(ActivatedAbility.new("{1}", false, [SelfCounter.new("+1/+1")],
				"{1}, Sacrifice another Thopter: Put a +1/+1 counter on this creature. Activate only as a sorcery.") \
				.with_sacrifice_of("another Thopter", _thopter).only_if(MA.sorcery_speed))
		_: return false
	return true


static func _noncreature(i: CardInstance) -> bool: return not i.is_creature()
static func _thopter(i: CardInstance) -> bool: return i.has_subtype("thopter")


# ------------------------------------------------------------ Coat of Arms --

## The pool's creature types, lower-cased the way cur_subtypes holds them —
## a land type an animated land carries (Forest) or an artifact type is not
## a creature type (CR 205.3m), so two animated Forests share none. Strings
## only: no CardData/CardInstance may live in a static (CONTRIBUTING).
static var _creature_types := {}

static func is_creature_type(subtype: String) -> bool:
	if _creature_types.is_empty():
		for type_name in TYPES.ALL: _creature_types[String(type_name).to_lower()] = true
	return _creature_types.has(subtype.to_lower())

## Layer 7c (CR 613.4c): creature types were settled in layer 4, so the
## count sees a Sliver Queen's or a retyped creature's live types. Each
## creature counts the OTHER creatures sharing at least one type with it.
static func _coat_of_arms(g: MtgGame, _s: CardInstance) -> void:
	var bodies: Array[CardInstance] = []
	var kinds: Array = []
	for i in g.all_battlefield():
		if not i.is_creature(): continue
		var own: Array[String] = []
		for sub in i.cur_subtypes:
			if is_creature_type(sub) and not own.has(sub): own.append(sub)
		bodies.append(i)
		kinds.append(own)
	for n in bodies.size():
		var mine: Array = kinds[n]
		if mine.is_empty(): continue
		var bonus := 0
		for m in bodies.size():
			if m == n: continue
			for sub in kinds[m]:
				if mine.has(sub):
					bonus += 1
					break
		bodies[n].cur_power += bonus
		bodies[n].cur_toughness += bonus


# --------------------------------------------------------------- Spellbook --

static func _no_maximum_hand_size(g: MtgGame, s: CardInstance) -> void:
	g.players[s.controller_id].max_hand_size = 999


# ---------------------------------------------------------------- effects --

## "Put a +1/+1 counter on this creature" — on the object that paid for it.
class SelfCounter extends CounterMarkerEffect:
	func _init(kind: String) -> void:
		super(kind)
		target_spec = null
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s): g.add_counters(s, kind, count)
	func describe() -> String: return "put a %s counter on this creature" % kind

## Erratic Portal: a bounce the creature's CONTROLLER may buy off with {1}
## (CR 118.12) — asked as the ability resolves, of the player who controls
## it then.
class PortalBounce extends ReturnToHandEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		if EffectBase.unless_paid(g, i.controller_id, ManaCost.parse("{1}"),
				"Erratic Portal: pay {1} to keep %s on the battlefield?" % i.data.card_name):
			g.log_line("%s's controller pays {1}" % i.data.card_name)
			return
		g.return_to_hand(i)
	func describe() -> String:
		return "return target creature to its owner's hand unless its controller pays {1}"

## Thopter Squadron's token: a 1/1 colorless Thopter ARTIFACT creature with
## flying (CR 111.4 — the token has exactly what the effect names).
class ThopterToken extends CreateTokenEffect:
	func _init() -> void:
		super("Thopter", 1, 1, 0, "thopter")
		token.types |= Mtg.CardType.ARTIFACT
		token.with_keywords([Mtg.Keyword.FLYING]).oracle("Flying")
	func describe() -> String:
		return "create a 1/1 colorless Thopter artifact creature token with flying"
