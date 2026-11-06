extends RefCounted
## Urza's Destiny (_auras, Pack 10). Auras: enchant a permanent and change it while attached.
##
## The shared helpers: cards/sets/mir/_auras.gd (A — host lookups, the
## trigger host capture, A.host_died) and cards/sets/usg/_auras.gd (U — the
## leave-to-graveyard condition, the counter-on-the-Aura upkeep question and
## the Aura's counters read live or as it last existed).
##
## - "When enchanted creature dies" (Private Research, Dying Wail,
##   Incendiary, Pattern of Rebirth) is heard by the Aura while it is still
##   attached; by the time the ability resolves the Aura has gone to the
##   graveyard (CR 704.5m), so "the number of <kind> counters on this
##   Aura" is read as it last existed on the battlefield (CR 608.2h,
##   [method U.aura_counters]).
## - The "you may put a <kind> counter on this Aura" upkeeps (Private
##   Research, Festering Wound, Incendiary, Momentum) ask the Aura's
##   controller; a growth/page/fuse/infection counter is no P/T counter.
## - Festering Wound: on the Aura controller's own creature both upkeep
##   triggers share one upkeep and its controller orders them (CR 603.3b).
## - Pattern of Rebirth: "that creature's controller" is the dead creature's
##   controller as it died (the DIES event's `controller`), who may be the
##   Aura controller's opponent; "may search" is asked before the search,
##   and declining skips the shuffle too.
## - Sigil of Sleep: "that player" is the damaged player. A trigger's target
##   is chosen as it goes on the stack (CR 603.3d), so the ability is two
##   triggers with complementary conditions (exo/_shadow.gd, Soltari
##   Visionary): the host damages an opponent of the Aura's controller →
##   target creature an opponent controls; it damages the Aura's controller
##   → target creature they control.
## - Chime of Night: the self-returning Auras' leave-to-graveyard condition
##   (CR 603.6c) with a target chosen by the Aura's last controller; an Aura
##   exiled instead never triggers.
## - Disappear: "{U}: Return enchanted creature and this Aura to their
##   owners' hands" — the creature the Aura enchanted when the ability was
##   activated and this very Aura, each only if it is still that object
##   (CR 400.7), returned together.
## - Mark of Fury: an end-step trigger with no "your" — every end step
##   (vis Viashino Sandstalker).
## - Mask of Law and Grace: CardData.grants_host_protection (layer 6 at the
##   Aura's timestamp).
## tests/cards/test_pack_10_B7_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")
const U := preload("res://cards/sets/usg/_auras.gd")

const SIGIL_TEXT := "Whenever enchanted creature deals damage to a player, return target creature that player controls to its owner's hand."

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Capashen Standard":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice this Aura: Draw a card.").with_sacrifice_cost())
		"Mask of Law and Grace":
			c.enchants(TargetSpec.creature())
			c.grants_host_protection(Mtg.ManaColor.B | Mtg.ManaColor.R,
				"Enchanted creature has protection from black and from red.")
		"Disappear":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{U}", false,
				[F.Action.new(_disappear, "return enchanted creature and this Aura to their owners' hands", null, true)],
				"{U}: Return enchanted creature and this Aura to their owners' hands."))
		"Illuminated Wings":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.FLYING]),
				"Enchanted creature has flying.").changing_abilities())
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice this Aura: Draw a card.").with_sacrifice_cost())
		"Private Research":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, U.may_add_counter.bind("page"),
				"At the beginning of your upkeep, you may put a page counter on this Aura.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _private_research,
				"When enchanted creature dies, draw a card for each page counter on this Aura.", A.host_died))
		"Sigil of Sleep":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _sigil, SIGIL_TEXT,
				_host_hit_opponent).targeting(TargetSpec.creature("target creature that player controls") \
					.with_source_filter(_opponents).because("controller"), _bigger_first,
				"Select a creature that player controls."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _sigil, SIGIL_TEXT,
				_host_hit_you).targeting(TargetSpec.creature("target creature that player controls") \
					.with_source_filter(_yours).because("controller"), _smaller_first,
				"Select a creature that player controls."))
		"Chime of Night":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _chime,
				"When this Aura is put into a graveyard from the battlefield, destroy target nonblack creature.",
				U.to_graveyard_from_battlefield).capturing(U.grave_context) \
				.targeting(TargetSpec.creature("target nonblack creature", _nonblack).because("color"),
					F._enemy_first, "Select a nonblack creature to destroy."))
		"Dying Wail":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _dying_wail,
				"When enchanted creature dies, target player discards two cards.", A.host_died) \
				.targeting(TargetSpec.player(), F._enemy_first, "Select a player to discard two cards."))
		"Festering Wound":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, U.may_add_counter.bind("infection"),
				"At the beginning of your upkeep, you may put an infection counter on this Aura.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _festering_wound,
				"At the beginning of the upkeep of enchanted creature's controller, this Aura deals X damage to that player, where X is the number of infection counters on this Aura.",
				U.host_controllers_upkeep))
		"Twisted Experiment":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(3, -1), "Enchanted creature gets +3/-1."))
		"Incendiary":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, U.may_add_counter.bind("fuse"),
				"At the beginning of your upkeep, you may put a fuse counter on this Aura.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _incendiary,
				"When enchanted creature dies, this Aura deals X damage to any target, where X is the number of fuse counters on this Aura.",
				A.host_died).targeting(TargetSpec.any_target(), F._enemy_first,
				"Incendiary: choose any target."))
		"Mark of Fury":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(A.host_keywords.bind([Mtg.Keyword.HASTE]),
				"Enchanted creature has haste.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _mark_of_fury,
				"At the beginning of the end step, return this Aura to its owner's hand."))
		"Momentum":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, U.may_add_counter.bind("growth"),
				"At the beginning of your upkeep, you may put a growth counter on this Aura.", F._your_upkeep))
			c.static_ability(StaticAbility.new(_momentum,
				"Enchanted creature gets +1/+1 for each growth counter on this Aura."))
		"Pattern of Rebirth":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _pattern_of_rebirth,
				"When enchanted creature dies, that creature's controller may search their library for a creature card, put that card onto the battlefield, then shuffle.",
				A.host_died).capturing(_dead_controller_context))
		_: return false
	return true


static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()

## "You": the Aura's controller as the ability triggered.
static func _you(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))


# ------------------------------------------------------------------ Disappear --

static func _disappear(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var host := A.paid_host(g, s)
	var aura_here := F._same_activation_source(g, s)
	if host == null and not aura_here: return
	g.begin_simultaneous()
	if host != null: g.return_to_hand(host)
	if aura_here and g.is_present(s): g.return_to_hand(s)
	g.end_simultaneous()


# ----------------------------------------------------------- Private Research --

static func _private_research(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var n := U.aura_counters(g, s, "page")
	if n > 0: g.draw_cards(_you(g, s), n)


# -------------------------------------------------------------- Sigil of Sleep --

static func _host_hit_opponent(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return U.host_is_source(s, e) and e.data.has("to_player") \
		and int(e.data.get("to_player", -1)) != s.controller_id

static func _host_hit_you(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return U.host_is_source(s, e) and e.data.has("to_player") \
		and int(e.data.get("to_player", -1)) == s.controller_id

static func _opponents(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id != g.controller_acting_for(s)

static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id == g.controller_acting_for(s)

## An opponent's creature: the biggest first; one's own: the smallest.
static func _bigger_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _size(g, a) > _size(g, b)

static func _smaller_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _size(g, a) < _size(g, b)

static func _size(g: MtgGame, ref: TargetRef) -> int:
	var i := g.find_instance(ref.instance_id) if ref != null and not ref.is_player else null
	return 0 if i == null else i.cur_power + i.cur_toughness

## The bounce is the trigger's effect: it happens even if the Aura has left
## by then (CR 603.6).
static func _sigil(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null: return
	var victim := g.find_instance((targets[0] as TargetRef).instance_id)
	if g.is_present(victim): g.return_to_hand(victim)


# -------------------------------------------------------------- Chime of Night --

static func _chime(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null: return
	var victim := g.find_instance((targets[0] as TargetRef).instance_id)
	if g.is_present(victim): g.destroy(victim)


# ------------------------------------------------------------------ Dying Wail --

static func _dying_wail(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null or not (targets[0] as TargetRef).is_player: return
	var who := (targets[0] as TargetRef).player_id
	var n := mini(2, g.players[who].hand.size())
	if n > 0: g.discard_cards(who, g.agents[who].choose_discard(g, who, n))


# ------------------------------------------------------------- Festering Wound --

## "That player": the enchanted creature's controller whose upkeep it is.
static func _festering_wound(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var x := U.aura_counters(g, s, "infection")
	if x > 0: g.deal_damage(s, TargetRef.player(int(e.data.get("player", g.active_player))), x)


# ------------------------------------------------------------------ Incendiary --

static func _incendiary(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	var x := U.aura_counters(g, s, "fuse")
	if targets.is_empty() or targets[0] == null or x <= 0: return
	g.deal_damage(s, targets[0], x)


# ---------------------------------------------------------------- Mark of Fury --

static func _mark_of_fury(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.return_to_hand(s)


# -------------------------------------------------------------------- Momentum --

static func _momentum(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	var n := int(s.counters.get("growth", 0))
	if i == null or n <= 0: return
	i.cur_power += n
	i.cur_toughness += n


# ---------------------------------------------------------- Pattern of Rebirth --

static func _dead_controller_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var dead: CardInstance = e.data.get("instance")
	out["searcher"] = int(e.data.get("controller", dead.controller_id if dead != null else s.controller_id))
	return out

## "May search": asked first (declining skips the shuffle as well). The
## hint is yes — a search that finds nothing costs only the shuffle.
static func _pattern_of_rebirth(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).get("searcher", s.controller_id))
	if pid < 0 or pid >= g.players.size(): return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Pattern of Rebirth: search your library for a creature card?", true):
		return
	g.search_library(pid, _creature_card, "Search your library for a creature card", true)
