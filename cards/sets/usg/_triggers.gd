extends RefCounted
## Urza's Saga (_triggers, Pack 10). Triggered abilities: enters, leaves, dies, upkeep and spell triggers.
##
## Same conventions as the Mirage and Tempest block modules
## (cards/sets/mir/_triggers.gd — whose shared helpers this reuses as M —
## and cards/sets/tmp/_triggers.gd):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it (M.pid_of) and dealing damage from the source as it last
##   existed. Only the clauses that name the source itself ("return this
##   creature", "sacrifice this creature", "put a counter on it", "target
##   opponent gains control of it") check that the very same object is
##   still there (F._same_trigger_source).
## - An intervening "if" (CR 603.4 — Imaginary Pet, Reclusive Wight) is the
##   trigger's condition AND a recheck on resolution.
## - A targeted trigger names its target as it goes on the stack and is
##   removed when nothing is legal (CR 603.3d); a mandatory "target
##   enchantment" with only its controller's own must take one of those.
##   Harmful targets are offered the other side's first (theirs_first).
## - "Whenever this creature deals damage to a player" hears DAMAGE_DEALT
##   (one packet per player per damage event); Flesh Reaver's "to a creature
##   or opponent" hears SOURCE_DEALT_DAMAGE, ONE trigger per damage event for
##   the qualifying total (the bug campaign c12, h3-8). "Blocks or becomes
##   blocked" is BECOMES_BLOCKER / BECOMES_BLOCKED once each; "becomes
##   blocked by a creature" is one BLOCKED trigger per blocking creature
##   (cards/sets/mir/_combat.gd, whose helpers this reuses as MC).
## - "Sacrifice this creature unless you <sacrifice or discard>" is paid on
##   resolution through MtgGame.unless_objects_paid (an "unless" payment,
##   CR 118.12: its discard is not one an effect causes — Library of Leng
##   has no say, a discard watcher still sees it). A source that has left
##   has nothing left to keep and is not asked (the Mirage precedent).
## - Deterministic public damage aftermath with no choice (Flesh Reaver,
##   Electryte) is marked `public_aftermath` so the AI's combat forecast may
##   resolve it; nothing with a choice, a coin or a draw is.
## The Urza's Destiny module (cards/sets/uds/_triggers.gd) reuses the shared
## helpers at the bottom of this file. tests/cards/test_pack_10_B5_*.gd pin
## every card here.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")
const OC := preload("res://engine/additional_object_costs.gd")
const P := preload("res://cards/sets/ice/_patterns.gd")

const ETB := Mtg.EventType.ENTERS_BATTLEFIELD
const DIES := Mtg.EventType.DIES
const UPKEEP := Mtg.EventType.UPKEEP_START

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Monk Idealist":
			c.triggered(TriggeredAbility.new(ETB, return_card_targets,
				"When this creature enters, return target enchantment card from your graveyard to your hand.",
				F._self_enter).targeting(graveyard_card_spec(Mtg.CardType.ENCHANTMENT,
					"target enchantment card from your graveyard"), best_card_first,
					"Monk Idealist: select target enchantment card in your graveyard."))
		"Monk Realist":
			c.triggered(TriggeredAbility.new(ETB, destroy_targets,
				"When this creature enters, destroy target enchantment.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", enchantment),
					theirs_first, "Monk Realist: select target enchantment to destroy."))
		# ------------------------------------------------------------- blue
		"Academy Researchers":
			c.triggered(TriggeredAbility.new(ETB, _researchers,
				"When this creature enters, you may put an Aura card from your hand onto the battlefield attached to this creature.",
				F._self_enter))
		"Imaginary Pet":
			c.triggered(TriggeredAbility.new(UPKEEP, _pet,
				"At the beginning of your upkeep, if you have a card in hand, return this creature to its owner's hand.",
				_pet_if))
		"Spire Owl":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(ETB, _spire_owl,
				"When this creature enters, look at the top four cards of your library, then put them back in any order.",
				F._self_enter))
		"Stern Proctor":
			c.triggered(TriggeredAbility.new(ETB, bounce_targets,
				"When this creature enters, return target artifact or enchantment to its owner's hand.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT,
					"target artifact or enchantment", artifact_or_enchantment), theirs_first,
					"Stern Proctor: select target artifact or enchantment to return to its owner's hand."))
		# ------------------------------------------------------------ black
		"Abyssal Horror":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(ETB, _horror,
				"When this creature enters, target player discards two cards.", F._self_enter) \
				.targeting(TargetSpec.player(), F._enemy_first, "Abyssal Horror: select target player."))
		"Cackling Fiend":
			c.triggered(TriggeredAbility.new(ETB, _cackling_fiend,
				"When this creature enters, each opponent discards a card.", F._self_enter))
		"Dark Hatchling":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(ETB, _hatchling,
				"When this creature enters, destroy target nonblack creature. It can't be regenerated.",
				F._self_enter).targeting(TargetSpec.creature("target nonblack creature", _nonblack),
					theirs_first, "Dark Hatchling: select target nonblack creature to destroy."))
		"Flesh Reaver":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SOURCE_DEALT_DAMAGE, _reaver,
				"Whenever this creature deals damage to a creature or opponent, this creature deals that much damage to you.",
				_reaver_hit).capturing(_reaver_context).public_aftermath())
		"Hollow Dogs", "Ravenous Skirge":
			# Ravenous Skirge's scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, MC._self_pump.bind(2, 0),
				"Whenever this creature attacks, it gets +2/+0 until end of turn.", F._self_attack))
		"Order of Yawgmoth":
			# The scaffold prints fear.
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, that_player_discards,
				"Whenever this creature deals damage to a player, that player discards a card.", hits_a_player))
		"Priest of Gix":
			c.triggered(TriggeredAbility.new(ETB, add_mana.bind(Mtg.ManaColor.B, 3),
				"When this creature enters, add {B}{B}{B}.", F._self_enter))
		"Reclusive Wight":
			c.triggered(TriggeredAbility.new(UPKEEP, _wight,
				"At the beginning of your upkeep, if you control another nonland permanent, sacrifice this creature.",
				_wight_if))
		"Skittering Skirge":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, M.sacrifice_source,
				"When you cast a creature spell, sacrifice this creature.", you_cast_a_creature_spell))
		"Sleeper Agent":
			c.triggered(TriggeredAbility.new(ETB, give_self_to_target,
				"When this creature enters, target opponent gains control of it.", F._self_enter) \
				.targeting(TargetSpec.opponent(), Callable(), "Sleeper Agent: select target opponent."))
			c.triggered(TriggeredAbility.new(UPKEEP, M.self_damage.bind(2),
				"At the beginning of your upkeep, this creature deals 2 damage to you.", F._your_upkeep))
		"Spined Fluke":
			c.triggered(TriggeredAbility.new(ETB, _fluke,
				"When this creature enters, sacrifice a creature.", F._self_enter))
			c.activated(ActivatedAbility.new("{B}", false, [RegenerateEffect.new()],
				"{B}: Regenerate this creature."))
		"Vebulid":
			c.with_enters_counters("+1/+1", 1)
			c.triggered(TriggeredAbility.new(UPKEEP, _vebulid_grow,
				"At the beginning of your upkeep, you may put a +1/+1 counter on this creature.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _doom_self,
				"When this creature attacks or blocks, destroy it at end of combat.", F._self_attack))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _doom_self,
				"When this creature attacks or blocks, destroy it at end of combat.", F._self_enter))
		# -------------------------------------------------------------- red
		"Dromosaur":
			MC.self_combat_pump(c, 2, -2,
				"Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.")
		"Electryte":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _electryte,
				"Whenever this creature deals combat damage to defending player, it deals damage equal to its power to each blocking creature.",
				_electryte_hit).public_aftermath())
		"Goblin Cadets":
			for type in [Mtg.EventType.BECOMES_BLOCKER, Mtg.EventType.BECOMES_BLOCKED]:
				c.triggered(TriggeredAbility.new(type, give_self_to_target,
					"Whenever this creature blocks or becomes blocked, target opponent gains control of it. (This removes this creature from combat.)",
					F._self_enter).targeting(TargetSpec.opponent(), Callable(), "Goblin Cadets: select target opponent."))
		"Goblin Lackey":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _lackey,
				"Whenever this creature deals damage to a player, you may put a Goblin permanent card from your hand onto the battlefield.",
				hits_a_player))
		"Retromancer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _retromancer,
				"Whenever this creature becomes the target of a spell or ability, this creature deals 3 damage to that spell or ability's controller.",
				M.targeted_me))
		"Scoria Wurm":
			c.triggered(TriggeredAbility.new(UPKEEP, _scoria,
				"At the beginning of your upkeep, flip a coin. If you lose the flip, return this creature to its owner's hand.",
				F._your_upkeep))
		"Viashino Weaponsmith":
			c.triggered(MC.pair_trigger(MC.BLOCKED_BY, Callable(), MC._self_pump.bind(2, 2),
				"Whenever this creature becomes blocked by a creature, this creature gets +2/+2 until end of turn."))
		# ------------------------------------------------------------ green
		"Argothian Enchantress":
			# Shroud is no CardData keyword: a static, Pincher Beetles' shape
			# (cards/sets/tmp/_creatures.gd).
			c.static_ability(StaticAbility.new(_shroud, "Shroud.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, draw_one,
				"Whenever you cast an enchantment spell, draw a card.", _you_cast_an_enchantment_spell))
		"Argothian Wurm":
			# The scaffold prints trample.
			c.triggered(TriggeredAbility.new(ETB, _argothian_wurm,
				"When this creature enters, any player may sacrifice a land of their choice. If a player does, put this creature on top of its owner's library.",
				F._self_enter))
		"Cave Tiger":
			c.triggered(MC.pair_trigger(MC.BLOCKED_BY, Callable(), MC._self_pump.bind(1, 1),
				"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn."))
		"Child of Gaea":
			# The scaffold prints trample.
			c.triggered(TriggeredAbility.new(UPKEEP, F._upkeep_payment.bind("{G}{G}"),
				"At the beginning of your upkeep, sacrifice this creature unless you pay {G}{G}.", F._your_upkeep))
			c.activated(ActivatedAbility.new("{1}{G}", false, [RegenerateEffect.new()],
				"{1}{G}: Regenerate this creature."))
		"Endless Wurm":
			# The scaffold prints trample.
			c.triggered(TriggeredAbility.new(UPKEEP, _endless_wurm,
				"At the beginning of your upkeep, sacrifice this creature unless you sacrifice an enchantment.",
				F._your_upkeep))
		"Titania's Chosen":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, counter_on_self.bind("+1/+1"),
				"Whenever a player casts a green spell, put a +1/+1 counter on this creature.",
				M.spell_of.bind(Mtg.ManaColor.G)))
		# --------------------------------------------------------- artifact
		"Cathodion":
			c.triggered(TriggeredAbility.new(DIES, add_mana.bind(Mtg.ManaColor.C, 3),
				"When this creature dies, add {C}{C}{C}.", F._self_enter))
		"Karn, Silver Golem":
			MC.self_combat_pump(c, -4, 4, "Whenever Karn blocks or becomes blocked, it gets -4/+4 until end of turn.")
			c.activated(ActivatedAbility.new("{1}", false, [F.Action.new(_karn_animate,
				"target noncreature artifact becomes an artifact creature with power and toughness each equal to its mana value until end of turn",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target noncreature artifact", _noncreature_artifact))],
				"{1}: Target noncreature artifact becomes an artifact creature with power and toughness each equal to its mana value until end of turn."))
		"Wall of Junk":
			# The scaffold prints defender.
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _junk_wall,
				"When this creature blocks, return it to its owner's hand at end of combat. (Return it only if it's on the battlefield.)",
				F._self_enter))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --
# Shared with cards/sets/uds/_triggers.gd.

static func enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func artifact_or_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)
static func land(i: CardInstance) -> bool: return i.is_land()
static func not_source(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i != s

## A card in a graveyard has only its printed characteristics (CR 109.3).
static func card_of_type(i: CardInstance, type: int) -> bool: return i.data.is_type(type)

## "target <kind> card from your graveyard".
static func graveyard_card_spec(type: int, desc: String) -> TargetSpec:
	return TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, desc, card_of_type.bind(type))

## A HELPFUL card target: the costliest card first.
static func best_card_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	return ai.data.cost.mana_value() > bi.data.cost.mana_value()

## A targeted trigger's preference for a HARMFUL target: the other side's
## permanents first, the costliest first; then its own, the cheapest first.
static func theirs_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.controller_acting_for(s)
	return _harm_value(g, me, a) > _harm_value(g, me, b)

static func _harm_value(g: MtgGame, me: int, ref: TargetRef) -> float:
	var i := g.find_instance(ref.instance_id) if not ref.is_player else null
	if i == null: return -10000.0
	var worth := float(i.data.cost.mana_value()) + (float(i.cur_power + i.cur_toughness) if i.is_creature() else 0.0)
	return 1000.0 + worth if i.controller_id != me else -worth

## "Return target <kind> card from your graveyard to your hand" — the card
## named, if it is still in a graveyard (the engine fizzles it otherwise).
static func return_card_targets(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var card := g.find_instance((t as TargetRef).instance_id)
		if card != null and card.zone == Mtg.Zone.GRAVEYARD:
			g.return_from_graveyard_to_hand(card)

static func destroy_targets(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(victim): g.destroy(victim)

static func bounce_targets(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(victim): g.return_to_hand(victim)

## "Target creature gets +P/+T until end of turn" (Disease Carriers, Marker
## Beetles) — the affected creature is fixed as it resolves (CR 611.2c).
static func pump_targets(g: MtgGame, s: CardInstance, _e: GameEvent, power: int, toughness: int) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if not g.is_present(victim): continue
		g.continuous.add_until_eot_pump(victim.id, power, toughness)
		g.log_line("%s gets %+d/%+d until end of turn (%s)" % [victim.data.card_name, power, toughness, s.data.card_name], victim)
	g.recalculate()

static func draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)

## "Add {X}{X}{X}" from a trigger — it uses the stack (it is not a mana
## ability, CR 605.1b) and the mana is its controller's, lost as the step
## ends (CR 500.4).
static func add_mana(g: MtgGame, s: CardInstance, _e: GameEvent, color: int, amount: int) -> void:
	AddManaEffect.new(color, amount).resolve(g, s, M.pid_of(g, s), null)

## "Put a <kind> counter on this creature" — only the same object.
static func counter_on_self(g: MtgGame, s: CardInstance, _e: GameEvent, kind: String) -> void:
	if F._same_trigger_source(g, s):
		g.add_counters(s, kind)

## "Target opponent gains control of it" (Sleeper Agent, Goblin Cadets): only
## the object that triggered, and a control change takes it out of combat
## (CR 506.4). A creature it was blocking stays blocked (CR 509.1h).
static func give_self_to_target(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	for t in g.current_targets():
		var ref := t as TargetRef
		if ref.is_player:
			g.change_control(s, ref.player_id)

static func you_cast_a_creature_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return int(e.data.get("controller", -1)) == s.controller_id and spell != null and spell.is_creature()

## "Deals damage to a player" — any player, its own controller too.
static func hits_a_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and e.data.has("to_player") and int(e.data.get("amount", 0)) > 0

## "Deals damage to an opponent" — not its own controller.
static func hits_an_opponent(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return hits_a_player(g, s, e) and int(e.data.to_player) != s.controller_id

## "That player discards a card" — of their own choice.
static func that_player_discards(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("to_player", -1))
	if who >= 0 and not g.players[who].hand.is_empty():
		g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))

## The seat's own permanents, cheapest-to-lose first: tokens, then lands,
## then the smallest bodies; [param keep] last. The order a heuristic seat
## answers "sacrifice a permanent / creature" in.
static func least_valuable_first(list: Array[CardInstance], keep: CardInstance = null) -> void:
	list.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if (a == keep) != (b == keep): return b == keep
		if a.is_token != b.is_token: return a.is_token
		return _keep_value(a) < _keep_value(b))

static func _keep_value(i: CardInstance) -> int:
	var worth := i.data.cost.mana_value()
	if i.is_creature(): worth += i.cur_power + i.cur_toughness
	if i.is_land(): worth += 2
	return worth

## "Sacrifice [param count] <desc>" — chosen by [param pid] among the
## permanents they control passing [param filter], one at a time, then
## sacrificed together (one event).
static func sacrifice_some(g: MtgGame, pid: int, filter: Callable, desc: String, count := 1,
		keep: CardInstance = null) -> void:
	var pool: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if g.is_present(i) and filter.call(i): pool.append(i)
	least_valuable_first(pool, keep)
	var picked: Array[CardInstance] = []
	for n in mini(count, pool.size()):
		picked.append(M.pick(g, pid, pool,
			"%s (%d of %d)" % [desc, n + 1, mini(count, pool.size())] if count > 1 else desc))
		pool.erase(picked[-1])
	if picked.is_empty(): return
	g.begin_simultaneous()
	for i in picked: g.sacrifice_permanent(i)
	g.end_simultaneous()


# --------------------------------------------------------- Academy Researchers --

## "You may put an Aura card from your hand onto the battlefield attached to
## this creature": not cast and not targeted (CR 303.4f — shroud does not
## matter), so only an Aura that could legally enchant the Researchers as
## they are now is offered (its own enchant restriction, and not one whose
## color the creature has protection from, CR 303.4g). None if the
## Researchers have left. The hint takes a helpful Aura only.
static func _researchers(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := M.pid_of(g, s)
	var auras: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_aura() and g.aura_can_enchant(card, s) and (s.cur_protection & card.cur_colors) == 0:
			auras.append(card)
	if auras.is_empty(): return
	auras.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var a_kind := EffectIntent.aura_aim(a.data) != EffectIntent.Aim.HOSTILE
		var b_kind := EffectIntent.aura_aim(b.data) != EffectIntent.Aim.HOSTILE
		if a_kind != b_kind: return a_kind
		return a.data.cost.mana_value() > b.data.cost.mana_value())
	var helpful := EffectIntent.aura_aim(auras[0].data) != EffectIntent.Aim.HOSTILE
	if not g.agents[pid].choose_yes_no(g, pid,
			"Academy Researchers: put an Aura card from your hand onto the battlefield attached to it?", helpful):
		return
	var aura := M.pick(g, pid, auras, "Academy Researchers: choose an Aura card to put onto the battlefield")
	g.attach_aura_from_anywhere(aura, s, pid)


# --------------------------------------------------------------- Imaginary Pet --

static func _hand_not_empty(g: MtgGame, pid: int) -> bool:
	return not g.players[pid].hand.is_empty()

static func _pet_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _hand_not_empty(g, s.controller_id)

## The intervening "if", rechecked on resolution (CR 603.4).
static func _pet(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if _hand_not_empty(g, M.pid_of(g, s)) and F._same_trigger_source(g, s):
		g.return_to_hand(s)


# ------------------------------------------------------------------- Spire Owl --

## A private look (only its controller sees the cards), then the same
## seat orders them, next draw first (Sage Owl's shape, wth/_triggers.gd).
static func _spire_owl(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var cards := P.top(g, pid, 4)
	if cards.is_empty(): return
	var names: Array = []
	for i in cards: names.append(i.data.card_name)
	g.reveal_information(pid, "Spire Owl — top of your library, top first", names)
	P.order(g, pid, pid, cards)


# -------------------------------------------------------------- Abyssal Horror --

## "Target player discards two cards" — that player chooses them.
static func _horror(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var who := (t as TargetRef).player_id
		if who >= 0 and not g.players[who].hand.is_empty():
			g.discard_cards(who, g.agents[who].choose_discard(g, who, 2))


# -------------------------------------------------------------- Cackling Fiend --

static func _cackling_fiend(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := g.opponent_of(M.pid_of(g, s))
	if not g.players[who].hand.is_empty():
		g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))


# -------------------------------------------------------------- Dark Hatchling --

static func _nonblack(i: CardInstance) -> bool: return not i.has_color(Mtg.ManaColor.B)

static func _hatchling(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(victim): g.destroy(victim, false)


# ---------------------------------------------------------------- Flesh Reaver --

## The damage of ONE event that went to a creature or to an opponent of
## [param me] — not to [param me] itself (a redirection into its own
## controller does not count).
static func _reaver_amount(e: GameEvent, me: int) -> int:
	var n := 0
	for packet in e.data.get("packets", []):
		var p := packet as DamagePacket
		if p == null or p.target == null: continue
		if p.target.is_player and p.target.player_id == me: continue
		n += p.remaining()
	return n

static func _reaver_hit(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and _reaver_amount(e, s.controller_id) > 0

static func _reaver_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["amount"] = _reaver_amount(e, s.controller_id)
	return ctx

## "That much damage to you" — from the Reaver as it last existed if the
## damage killed it; "you" is the seat that controlled the trigger.
static func _reaver(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var amount := int(g.trigger_context(s).get("amount", 0))
	if amount > 0:
		g.deal_damage(s, TargetRef.player(M.pid_of(g, s)), amount)


# ------------------------------------------------------------- Reclusive Wight --

static func _another_nonland(g: MtgGame, s: CardInstance, pid: int) -> bool:
	for i in g.players[pid].battlefield:
		if i != s and g.is_present(i) and not i.is_land(): return true
	return false

static func _wight_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _another_nonland(g, s, s.controller_id)

## The intervening "if", rechecked on resolution (CR 603.4).
static func _wight(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if _another_nonland(g, s, M.pid_of(g, s)):
		M.sacrifice_source(g, s, e)


# ---------------------------------------------------------------- Spined Fluke --

## "Sacrifice a creature" — any creature its controller controls, the Fluke
## itself included (offered last; with no other creature it must go).
static func _fluke(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var keep := s if F._same_trigger_source(g, s) else null
	sacrifice_some(g, M.pid_of(g, s), func(i: CardInstance) -> bool: return i.is_creature(),
		"Spined Fluke: sacrifice a creature", 1, keep)


# --------------------------------------------------------------------- Vebulid --

static func _vebulid_grow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := M.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Put a +1/+1 counter on Vebulid?", true):
		g.add_counters(s, "+1/+1")

## "Destroy it at end of combat" — regeneration applies (a destruction).
static func _doom_self(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.doom_at_end_of_combat(s)


# ------------------------------------------------------------------- Electryte --

## Combat damage to the DEFENDING player (CR 506.2: the active player's
## opponent while combat lasts).
static func _electryte_hit(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if not hits_a_player(g, s, e): return false
	var packet: DamagePacket = e.data.get("packet")
	return packet != null and packet.is_combat and int(e.data.to_player) == g.opponent_of(g.active_player)

## "Each blocking creature" — every creature blocking any attacker (CR
## 509.1), as the ability resolves; damage equal to its power then (its
## last known power if it has left, CR 608.2h), one event.
static func _electryte(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var power := s.cur_power if F._same_trigger_object(g, s) else s.last_power
	if power <= 0: return
	var victims: Array[CardInstance] = []
	for id in g.combat.blocks:
		var i := g.find_instance(int(id))
		if g.is_present(i) and i.is_creature(): victims.append(i)
	if victims.is_empty(): return
	g.begin_simultaneous()
	for i in victims: g.deal_damage(s, TargetRef.card(i), power)
	g.end_simultaneous()


# ---------------------------------------------------------------- Goblin Lackey --

## "You may put a Goblin permanent card from your hand onto the
## battlefield" — not cast. The Goblin permanent cards of the pool are all
## creatures; the biggest is offered first.
static func _lackey(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var goblins: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_permanent_type() and not card.data.is_aura() and card.data.subtypes.has("goblin"):
			goblins.append(card)
	if goblins.is_empty(): return
	goblins.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value())
	if not g.agents[pid].choose_yes_no(g, pid,
			"Goblin Lackey: put a Goblin permanent card from your hand onto the battlefield?", true):
		return
	g.put_from_hand_into_play(M.pick(g, pid, goblins, "Goblin Lackey: choose a Goblin to put onto the battlefield"), pid)


# ----------------------------------------------------------------- Retromancer --

## "That spell or ability's controller" — the targeting object's, read from
## the event (its own controller too, when he aims at it himself). From the
## Retromancer as it last existed if it has left.
static func _retromancer(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0:
		g.deal_damage(s, TargetRef.player(who), 3)


# ----------------------------------------------------------------- Scoria Wurm --

## The flip is made even when the Wurm has gone; only a lost flip returns
## it, and only the same object.
static func _scoria(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if g.flip_coin(M.pid_of(g, s)): return
	if F._same_trigger_source(g, s):
		g.return_to_hand(s)


# ------------------------------------------------------- Argothian Enchantress --

static func _shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true

static func _you_cast_an_enchantment_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return int(e.data.get("controller", -1)) == s.controller_id and spell != null \
		and spell.is_type(Mtg.CardType.ENCHANTMENT)


# -------------------------------------------------------------- Argothian Wurm --

## "Any player may sacrifice a land of their choice": asked in APNAP order
## (CR 101.4); the first player who does sends the Wurm to the top of its
## owner's library and nobody else is asked. A Wurm that has already left
## has nothing to send: nobody is asked. The hint: never the Wurm's own
## controller; an opponent with four or more lands pays.
static func _argothian_wurm(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var owner_side := M.pid_of(g, s)
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		var lands := 0
		for i in g.players[who].battlefield:
			if i.is_land() and g.is_present(i): lands += 1
		var hint: bool = who != owner_side and lands >= 4
		if g.unless_objects_paid(who, s, [OC.sacrificing("land", land)],
				"Argothian Wurm: sacrifice a land to put Argothian Wurm on top of its owner's library?", hint):
			if F._same_trigger_source(g, s):
				g.return_permanent_to_library_top(s)
			return


# ---------------------------------------------------------------- Endless Wurm --

## "Unless you sacrifice an enchantment" — an animated enchantment is still
## one (Opalescence). The hint keeps the Wurm.
static func _endless_wurm(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not F._same_trigger_source(g, s) or s.controller_id != pid: return
	if g.unless_objects_paid(pid, s, [OC.sacrificing("enchantment", enchantment)],
			"Endless Wurm: sacrifice an enchantment? (otherwise sacrifice Endless Wurm)", true):
		return
	g.sacrifice_permanent(s)


# ---------------------------------------------------------- Karn, Silver Golem --

static func _noncreature_artifact(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) and not i.is_creature()

## Layer 4 (types) and 7b (base P/T) until end of turn, on the timestamp
## clock against Humility (Pack 9 E5). The mana value is the target's as
## the ability resolves; a 0-value artifact becomes 0/0 and dies.
static func _karn_animate(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id) if t != null else null
	if not g.is_present(i): return
	var mv := i.data.cost.mana_value()
	g.continuous.add_until_eot_animation(i.id, Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE, mv, mv)
	g.log_line("%s becomes a %d/%d artifact creature until end of turn" % [i.data.card_name, mv, mv], i)
	g.recalculate()


# ---------------------------------------------------------------- Wall of Junk --

## One delayed trigger (CR 603.7) at the end of this combat that returns
## THIS object if it is still on the battlefield (CR 400.7) — the Wall of
## Tears shape (sth/_combat.gd).
static func _junk_wall(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_junk_return.bind(s.id, s.layer_timestamp), "Return Wall of Junk to its owner's hand."),
		M.pid_of(g, s), s)

static func _junk_return(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if g.is_present(i) and i.layer_timestamp == stamp:
		g.return_to_hand(i)
