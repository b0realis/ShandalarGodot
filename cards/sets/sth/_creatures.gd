extends RefCounted
## Stronghold (_creatures, Pack 9). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd). The redirects and Silver Wyvern's retarget
## are card-local effect classes the AI does not activate yet (an unknown
## effect scores nothing, AiPlayer._ability_option); their policy belongs
## to the pack's AI stage. tests/cards/test_pack_9_B9_creatures.gd pins
## each card's distinguishing clause and its edges.
##
## THE EN-KOR CYCLE. "{0}: The next 1 damage that would be dealt to this
## creature this turn is dealt to target creature you control instead" is a
## METERED redirection (MtgGame.redirect_next_damage_points, Pack 8's
## Zhalfirin Crusader): one point of a later damage event moves to the
## target, the rest of that event carries on. Each activation books one
## point; the destination is the target as it was chosen (CR 400.7), and a
## destination that has left (or is the en-Kor itself) moves nothing (CR
## 614.6). Shaman en-Kor's second ability is the whole-event redirect onto
## itself from a source chosen on resolution (CR 615.8's "the next time").
## Both are of the 1997 damage-prevention family (`is_damage_prevention`,
## docs/duel-todo.md §6.8): they may be used inside that window.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const MCR := preload("res://cards/sets/mir/_creatures.gd")
const VS := preload("res://cards/sets/vis/_spells.gd")
const DFX := preload("res://engine/damage_replacements.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Honor Guard":
			c.activated(ActivatedAbility.new("{W}", false, [PumpEffect.new(0, 1).self_buff()],
				"{W}: This creature gets +0/+1 until end of turn."))
		"Lancers en-Kor", "Nomads en-Kor", "Spirit en-Kor", "Warrior en-Kor":
			# The scaffold prints the keywords (Lancers' trample, Spirit's flying).
			c.activated(_en_kor())
		"Shaman en-Kor":
			c.activated(_en_kor())
			c.activated(ActivatedAbility.new("{1}{W}", false, [ShamanRedirect.new()],
				"{1}{W}: The next time a source of your choice would deal damage to target creature this turn, that damage is dealt to this creature instead."))
		# ----------------------------------------------------------- blue
		"Silver Wyvern":
			# The scaffold prints flying. Pack 9 E7: a spell, an activated or a
			# triggered ability that targets only the Wyvern.
			c.activated(ActivatedAbility.new("{U}", false, [WyvernRetarget.new()],
				"{U}: Change the target of target spell or ability that targets only this creature. The new target must be a creature."))
		"Tidal Warrior":
			# Kukemssa Serpent's retype (mir/_creatures.gd): the land becomes an
			# Island — it loses its other land types and their mana abilities
			# (CR 305.7) — until end of turn.
			var land := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(MCR._islandify, "target land becomes an Island until end of turn", land)],
				"{T}: Target land becomes an Island until end of turn."))
		"Walking Dream":
			# "Can't be blocked" is the engine's UNBLOCKABLE keyword, which the
			# scaffold does not print. The untap lock is a static read at the
			# untap step: it asks about the board as it is then.
			c.with_keywords([Mtg.Keyword.UNBLOCKABLE])
			c.static_ability(StaticAbility.new(_walking_dream,
				"This creature doesn't untap during your untap step if an opponent controls two or more creatures."))
		# ---------------------------------------------------------- black
		"Dungeon Shade":
			c.activated(ActivatedAbility.new("{B}", false, [PumpEffect.new(1, 1).self_buff()],
				"{B}: This creature gets +1/+1 until end of turn."))
		"Mindwarper":
			# The counter is a COST (CR 601.2h, ActivatedAbility.with_counter_cost);
			# the discard is the target player's choice (Disrupting Scepter's shape).
			c.with_enters_counters("+1/+1", 3)
			c.activated(ActivatedAbility.new("{2}{B}", false, [VS.TargetDiscard.new()],
				"{2}{B}, Remove a +1/+1 counter from this creature: Target player discards a card. Activate only as a sorcery.") \
				.with_counter_cost("+1/+1").only_if(MA.sorcery_speed))
		"Morgue Thrull":
			# "Mill three cards" is the activator's own library. A card-local
			# action, not a MillEffect: the AI reads a MillEffect as milling the
			# player it is aimed at (EffectIntent.mills), and this one is aimed
			# at nobody but us.
			c.activated(ActivatedAbility.new("", false, [F.Action.new(_mill_three, "mill three cards")],
				"Sacrifice this creature: Mill three cards.").with_sacrifice_cost())
		"Revenant":
			# The scaffold prints flying. A characteristic-defining ability
			# (CR 604.3, layer 7a): cards in a graveyard have their printed
			# characteristics.
			c.static_ability(StaticAbility.new(_revenant,
				"Revenant's power and toughness are each equal to the number of creature cards in your graveyard.").setting_base_pt())
		"Skeleton Scavengers":
			# "Pay {1} for each +1/+1 counter" is an {X} that must equal the
			# counters (Voodoo Doll's ActivatedAbility.with_x_condition): X is
			# announced with the activation and checked before anything is paid.
			c.with_enters_counters("+1/+1", 1)
			c.activated(ActivatedAbility.new("{X}", false, [ScavengerRegeneration.new()],
				"Pay {1} for each +1/+1 counter on this creature: Regenerate this creature. When it regenerates this way, put a +1/+1 counter on it.") \
				.with_x_condition(_x_is_the_counters))
		"Stronghold Assassin":
			# "Sacrifice a creature" may be the Assassin itself (CR 602.2b: the
			# target is chosen before the costs are paid).
			c.activated(ActivatedAbility.new("", true,
				[DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack))],
				"{T}, Sacrifice a creature: Destroy target nonblack creature.") \
				.with_sacrifice_of("creature", F._creature).may_sacrifice_itself())
		"Stronghold Taskmaster":
			c.static_ability(StaticAbility.new(_taskmaster, "Other black creatures get -1/-1."))
		# ------------------------------------------------------------ red
		"Flowstone Hellion":
			# The scaffold prints haste.
			c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(1, -1).self_buff()],
				"{0}: This creature gets +1/-1 until end of turn."))
		"Flowstone Mauler", "Flowstone Shambler":
			# The scaffold prints the Mauler's trample.
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, -1).self_buff()],
				"{R}: This creature gets +1/-1 until end of turn."))
		"Furnace Spirit":
			# The scaffold prints haste.
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Shard Phoenix":
			# The scaffold prints flying. The damage comes from the sacrificed
			# Phoenix as it last existed (CR 608.2h), as one event; the return
			# acts on the graveyard object that paid for it (CR 400.7).
			c.activated(ActivatedAbility.new("", false,
				[DamageAllEffect.new(2, "each creature without flying", _without_flying)],
				"Sacrifice this creature: It deals 2 damage to each creature without flying.").with_sacrifice_cost())
			c.activated(ActivatedAbility.new("{R}{R}{R}", false,
				[F.Action.new(_phoenix_home, "return this card from your graveyard to your hand", null, true)],
				"{R}{R}{R}: Return this card from your graveyard to your hand. Activate only during your upkeep.") \
				.from_graveyard().during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Spitting Hydra":
			c.with_enters_counters("+1/+1", 4)
			c.activated(ActivatedAbility.new("{1}{R}", false, [DamageEffect.new(1).target_creature()],
				"{1}{R}, Remove a +1/+1 counter from this creature: It deals 1 damage to target creature.") \
				.with_counter_cost("+1/+1"))
		# ---------------------------------------------------------- green
		"Carnassid":
			# The scaffold prints trample.
			c.activated(ActivatedAbility.new("{1}{G}", false, [RegenerateEffect.new()],
				"{1}{G}: Regenerate this creature."))
		"Endangered Armodon":
			# The pool's "when you control …, sacrifice this" shape: a state
			# check (CardData.sacrifices_when — Jihad, Sea Serpent). "A
			# creature" is any creature you control, the Armodon included.
			c.sacrifices_when(_armodon)
		"Skyshroud Archer":
			var shrink := PumpEffect.new(-1, -1)
			shrink.target_spec = TargetSpec.creature("target creature with flying", _flying)
			c.activated(ActivatedAbility.new("", true, [shrink],
				"{T}: Target creature with flying gets -1/-1 until end of turn."))
		_: return false
	return true


# ------------------------------------------------------------- filters --

static func _land(i: CardInstance) -> bool: return i.is_land()
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _without_flying(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)

## "You control" from the seat the ability acts for (a sacrificed source
## has gone home, MtgGame.controller_acting_for).
static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return i.controller_id == g.controller_acting_for(s)


# -------------------------------------------------------------- statics --

## Walking Dream: counted live, phased-out creatures as though they don't
## exist (CR 702.26b).
static func _walking_dream(g: MtgGame, s: CardInstance) -> void:
	var theirs := 0
	for i in g.all_battlefield():
		if i.controller_id != s.controller_id and i.is_creature() and g.is_present(i):
			theirs += 1
	if theirs >= 2:
		s.cur_skips_untap = true

static func _revenant(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for card in g.players[s.controller_id].graveyard:
		if card.data.is_creature():
			n += 1
	s.cur_power = n
	s.cur_toughness = n

## Every other black creature, either player's (layer 7c).
static func _taskmaster(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i != s and i.is_creature() and (i.cur_colors & Mtg.ManaColor.B) != 0:
			i.cur_power -= 1
			i.cur_toughness -= 1

## Endangered Armodon: live toughness, any creature its controller has.
static func _armodon(g: MtgGame, s: CardInstance) -> bool:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and g.is_present(i) and i.cur_toughness <= 2:
			return true
	return false


# -------------------------------------------------------------- actions --

## The en-Kor's {0}: a fresh ability object per card.
static func _en_kor() -> ActivatedAbility:
	return ActivatedAbility.new("{0}", false, [EnKorRedirect.new()],
		"{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.")

static func _mill_three(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.mill(pid, 3)

## The same graveyard object that paid the activation (CR 400.7) —
## Hammer of Bogardan's shape (mir/_spells.gd).
static func _phoenix_home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.cost_paid("_source_graveyard_entry", -1)):
		g.return_from_graveyard_to_hand(s)

## "Pay {1} for each +1/+1 counter on this creature" — the X named must be
## the count as the ability is activated (CR 601.2f).
static func _x_is_the_counters(_g: MtgGame, s: CardInstance, x_value: int, _targets: Array) -> String:
	var n := int(s.counters.get("+1/+1", 0))
	if x_value != n:
		return "X must be %d — the number of +1/+1 counters on %s" % [n, s.data.card_name]
	return ""


# -------------------------------------------------------------- effects --

## The en-Kor redirect (see the module header): one point of the next damage
## to this creature this turn goes to the target creature you control.
class EnKorRedirect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(_yours)
		is_damage_prevention = true
		ai_helpful = true
		ai_role = &"redirect_point_to_own"   # engine/ai/tempest_tactics.gd

	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return i.controller_id == g.controller_acting_for(s)

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not MA.same_activation(g, s):
			return
		g.redirect_next_damage_points(pid, s.data.card_name, s, 1, t)

	func describe() -> String:
		return "the next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead"


## Shaman en-Kor's second ability: "The next time a source of your choice
## would deal damage to target creature this turn, that damage is dealt to
## this creature instead." The source is named as the ability resolves
## (CR 609.7a; MtgGame.choose_damage_source ranks the one about to hit the
## creature first), and ONE damage event from it is moved whole onto the
## Shaman (CR 615.8) — or nothing, once the Shaman is not there to take it.
## A Shaman that has left by then names no source at all.
class ShamanRedirect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		is_damage_prevention = true
		ai_helpful = true

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var shielded := g.find_instance(t.instance_id) if t != null else null
		if not g.is_present(shielded) or not MA.same_activation(g, s):
			return
		var named := g.choose_damage_source(pid,
			"Shaman en-Kor: choose a source of damage to %s" % shielded.data.card_name,
			Callable(), TargetRef.card(shielded))
		if named == null:
			return
		g.add_damage_effect({"kind": DFX.KIND_REDIRECT, "one_shot": true,
			"controller": pid, "card": s.data.card_name, "source": named,
			"victims": [shielded], "to": s,
			"desc": "Shaman en-Kor (%s's damage to %s)" % [named.data.card_name, shielded.data.card_name]})

	func describe() -> String:
		return "the next time a source of your choice would deal damage to target creature this turn, that damage is dealt to this creature instead"


## Silver Wyvern (Pack 9 E7). The target is a spell, an activated or a
## triggered ability whose every target is this Wyvern
## (MtgGame.stack_item_targets_only). On resolution its one target changes
## to another creature that is legal for that object's OWN targeting
## (MtgGame.single_target_retargets — protection, "nonblack" and the rest
## still hold), chosen by the Wyvern's controller; with no such creature,
## or an object with more than one target, nothing changes (CR 115.7). The
## hint (Meddle's, mir/_spells.gd): a helpful object lands on our best
## creature, a harmful one on theirs.
class WyvernRetarget extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell_or_ability("target spell or ability that targets only this creature", _only_me)
		ai_role = &"retarget_from_self"   # engine/ai/tempest_tactics.gd

	static func _only_me(_g: MtgGame, source: CardInstance, item: StackItem) -> bool:
		return MtgGame.stack_item_targets_only(item, source)

	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var item := g.stack_item_for_ref(t)
		if item == null:
			return
		var options: Array[TargetRef] = []
		for ref in g.single_target_retargets(item):
			if ref.is_player:
				continue
			var other := g.find_instance(ref.instance_id)
			if other != null and other.zone == Mtg.Zone.BATTLEFIELD and other.is_creature():
				options.append(ref)
		if options.is_empty():
			return
		var helpful := false
		for effect in item.effects:
			if effect.target_spec != null:
				helpful = effect.ai_helpful or effect is PumpEffect or effect is RegenerateEffect \
					or effect is PreventDamageEffect
				break
		var labels: Array[String] = []
		var best := 0
		var top := -INF
		for n in options.size():
			var other := g.find_instance(options[n].instance_id)
			labels.append(other.data.card_name)
			var worth := float(maxi(1, other.data.cost.mana_value()) + maxi(0, other.cur_power) + maxi(0, other.cur_toughness))
			var score := worth if (other.controller_id == pid) == helpful else -worth
			if score > top:
				top = score
				best = n
		var at := g.agents[pid].choose_option(g, pid, labels, "Silver Wyvern: choose the new target (a creature)", best)
		g.retarget_stack_item(item.id, 0, options[clampi(at, 0, options.size() - 1)])

	func describe() -> String:
		return "change the target of target spell or ability that targets only this creature; the new target must be a creature"


## Skeleton Scavengers: "Regenerate this creature. When it regenerates this
## way, put a +1/+1 counter on it." The shield is the engine's ordinary one;
## the "this way" half is a delayed trigger per shield (CR 603.7), keyed to
## the creature's object (id + timestamp, CR 400.7) and expiring with the
## shield at cleanup (CR 701.15) — Matopi Golem's shape
## (vis/_creatures.gd ThisWayRegeneration).
## SIMPLIFIED (docs/simplified-cards.md, "Debt of Loyalty; Matopi Golem"):
## shields are interchangeable counts and CR 616.1's choice among them is
## not asked. Here the rider is a GAIN, so the opposite of the Golem's
## order is taken: while one of these shields is pending, the next
## regeneration of the creature is taken to have used it (the oldest).
class ScavengerRegeneration extends RegenerateEffect:
	const RIDER := "scavengers"

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef, x := 0) -> void:
		if not MA.same_activation(game, source):
			return
		var before := source.regeneration_shields
		super(game, source, controller, target, x)
		if source.regeneration_shields <= before:
			return
		var seq := game.continuous.next_timestamp()
		var memory := {"regenerated_this_way": RIDER, "id": source.id, "stamp": source.layer_timestamp, "seq": seq}
		var trigger := TriggeredAbility.new(Mtg.EventType.REGENERATED,
			ScavengerRegeneration._grow.bind(source.id, source.layer_timestamp),
			"When it regenerates this way, put a +1/+1 counter on it.",
			ScavengerRegeneration._this_way.bind(source.id, source.layer_timestamp, seq))
		var entry := game.schedule_delayed_trigger(trigger, controller, source, false, memory)
		entry["expires_turn"] = game.turn_number

	## The oldest pending entry of this object answers its regeneration.
	static func _this_way(g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int, seq: int) -> bool:
		var inst: CardInstance = e.data.get("instance")
		if inst == null or inst.id != id or inst.layer_timestamp != stamp:
			return false
		var first := seq
		for entry in g.delayed_triggers:
			var memory: Dictionary = entry.get("memory", {})
			if String(memory.get("regenerated_this_way", "")) == RIDER and int(memory.get("id", -1)) == id \
					and int(memory.get("stamp", -1)) == stamp:
				first = mini(first, int(memory.get("seq", seq)))
		return first == seq

	static func _grow(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var inst := g.find_instance(id)
		if g.is_present(inst) and inst.layer_timestamp == stamp:
			g.add_counters(inst, "+1/+1")

	func describe() -> String:
		return "regenerate this creature; when it regenerates this way, put a +1/+1 counter on it"
