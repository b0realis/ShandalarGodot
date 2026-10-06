extends RefCounted
## Tempest (_triggers, Pack 9). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Same conventions as the Mirage block modules (cards/sets/mir/_triggers.gd,
## whose shared helpers this reuses as M):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it (M.pid_of) and dealing damage from the source as it last
##   existed. Only the clauses that name the source itself ("put a counter
##   on it", "return this creature", "sacrifice it") check that the very
##   same object is still there (F._same_trigger_source).
## - An intervening "if" (CR 603.4 — Kezzerdrix, Sarcomancy, Spirit Mirror)
##   is the trigger's condition AND a recheck on resolution.
## - Per-occurrence facts (the creature that was dealt damage, how much, its
##   controller, the creature that entered) are captured as the ability
##   triggers, never read back later off a permanent that may have changed.
## - "Becomes the target of a spell or ability" hears BECAME_TARGET, which
##   the engine announces once per distinct target per stack object
##   (Angelic Protector, Segmented Wurm; Fugitive Druid narrows it to Aura
##   spells).
## - Deterministic public damage/death aftermath (Death Pits of Rath, Jackal
##   Pup, Bellowing Fiend, Field of Souls, Mongrel Pack) is marked
##   `public_aftermath` so the AI's combat forecast may resolve it; nothing
##   with a choice, a coin or a draw is.
## Unstable Shapeshifter is Vesuvan Doppelganger's "except it has this
## ability" (2ed/vesuvan_doppelganger.gd): MtgGame.become_copy with the
## trigger re-added through CardData.with_extra_trigger, built fresh each
## time. Recycle's "Skip your draw step" is a mandatory draw-step
## replacement (CardData.replaces_draw_step, drk/fasting.gd's shape) and
## "whenever you play a card" hears both SPELL_CAST and LAND_PLAYED.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Ancient Runes":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _runes,
				"At the beginning of each player's upkeep, this enchantment deals damage to that player equal to the number of artifacts they control."))
		"Angelic Protector":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _protector,
				"Whenever this creature becomes the target of a spell or ability, this creature gets +0/+3 until end of turn.",
				M.targeted_me))
		"Avenging Angel":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _avenging_angel,
				"When this creature dies, you may put it on top of its owner's library.",
				F._self_enter).capturing(M._dead_context))
		"Bellowing Fiend":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _fiend,
				"Whenever this creature deals damage to a creature, this creature deals 3 damage to that creature's controller and 3 damage to you.",
				_damages_a_creature).capturing(_victim_context).public_aftermath())
		"Chaotic Goo":
			c.with_enters_counters("+1/+1", 3)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _goo,
				"At the beginning of your upkeep, you may flip a coin. If you win the flip, put a +1/+1 counter on this creature. If you lose the flip, remove a +1/+1 counter from this creature.",
				F._your_upkeep))
		"Cloudchaser Eagle":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _destroy_targets,
				"When this creature enters, destroy target enchantment.", F._self_enter) \
				.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _enchantment),
					_theirs_first, "Destroy target enchantment."))
		"Commander Greven il-Vec":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _greven,
				"When Commander Greven il-Vec enters, sacrifice a creature.", F._self_enter))
		"Death Pits of Rath":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _death_pits,
				"Whenever a creature is dealt damage, destroy it. It can't be regenerated.",
				_creature_dealt_damage).capturing(_victim_context).public_aftermath())
		"Dirtcowl Wurm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LAND_PLAYED, _counter_on_self.bind("+1/+1"),
				"Whenever an opponent plays a land, put a +1/+1 counter on this creature.", _opponent_played_land))
		"Field of Souls":
			var spirit := CreateTokenEffect.new("Spirit", 1, 1, Mtg.ManaColor.W, "spirit")
			spirit.token.with_keywords([Mtg.Keyword.FLYING]).oracle("Flying")
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _make_tokens.bind(spirit),
				"Whenever a nontoken creature is put into your graveyard from the battlefield, create a 1/1 white Spirit creature token with flying.",
				M._own_nontoken_creature_died).public_aftermath())
		"Fugitive Druid":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _draw_one,
				"Whenever this creature becomes the target of an Aura spell, you draw a card.", _aura_spell_targets_me))
		"Havoc":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _havoc,
				"Whenever an opponent casts a white spell, they lose 2 life.", _opponent_spell.bind(Mtg.ManaColor.W)))
		"Insight":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _draw_one,
				"Whenever an opponent casts a green spell, you draw a card.", _opponent_spell.bind(Mtg.ManaColor.G)))
		"Jackal Pup":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _pup,
				"Whenever this creature is dealt damage, it deals that much damage to you.",
				_dealt_damage_me).capturing(_victim_context).public_aftermath())
		"Kezzerdrix":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _kezzerdrix,
				"At the beginning of your upkeep, if your opponents control no creatures, this creature deals 4 damage to you.",
				_kezzerdrix_if))
		"Legacy's Allure":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _allure_counter,
				"At the beginning of your upkeep, you may put a treasure counter on this enchantment.", F._your_upkeep))
			c.activated(ActivatedAbility.new("", false, [F.Action.new(_allure_steal,
				"gain control of target creature with power less than or equal to the number of treasure counters on this enchantment",
				TargetSpec.creature("target creature with power less than or equal to the number of treasure counters on Legacy's Allure") \
					.with_source_filter(_within_treasure)).with_ai_role(&"steal_creature")],
				"Sacrifice this enchantment: Gain control of target creature with power less than or equal to the number of treasure counters on this enchantment. (This effect lasts indefinitely.)") \
				.with_sacrifice_cost())
		"Magmasaur":
			c.with_enters_counters("+1/+1", 5)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _magmasaur,
				"At the beginning of your upkeep, you may remove a +1/+1 counter from this creature. If you don't, sacrifice this creature and it deals damage equal to the number of +1/+1 counters on it to each creature without flying and each player.",
				F._your_upkeep))
		"Mongrel Pack":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES,
				_make_tokens.bind(CreateTokenEffect.new("Dog", 1, 1, Mtg.ManaColor.G, "dog", 4)),
				"When this creature dies during combat, create four 1/1 green Dog creature tokens.",
				_dies_during_combat).public_aftermath())
		"Orim's Prayer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _prayer,
				"Whenever one or more creatures attack you, you gain 1 life for each attacking creature.", _attack_on_you))
		"Rathi Dragon":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _rathi_dragon,
				"When this creature enters, sacrifice it unless you sacrifice two Mountains.", F._self_enter))
		"Recycle":
			c.replaces_draw_step(_recycle_skip)
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _draw_one,
				"Whenever you play a card, draw a card.", _you_played_a_card).also_when(Mtg.EventType.LAND_PLAYED))
			c.static_ability(StaticAbility.new(_hand_size_two, "Your maximum hand size is two."))
		"Sarcomancy":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
				_make_tokens.bind(CreateTokenEffect.new("Zombie", 2, 2, Mtg.ManaColor.B, "zombie")),
				"When this enchantment enters, create a 2/2 black Zombie creature token.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _sarcomancy_bite,
				"At the beginning of your upkeep, if there are no Zombies on the battlefield, this enchantment deals 1 damage to you.",
				_sarcomancy_if))
		"Segmented Wurm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _counter_on_self.bind("-1/-1"),
				"Whenever this creature becomes the target of a spell or ability, put a -1/-1 counter on it.", M.targeted_me))
		"Servant of Volrath":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _servant,
				"When this creature leaves the battlefield, sacrifice a creature.", F._self_enter))
		"Shocker":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _shocker,
				"Whenever this creature deals damage to a player, that player discards all the cards in their hand, then draws that many cards.",
				_damages_a_player))
		"Spirit Mirror":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
				_spirit_mirror.bind(CreateTokenEffect.new("Reflection", 2, 2, Mtg.ManaColor.W, "reflection")),
				"At the beginning of your upkeep, if there are no Reflection tokens on the battlefield, create a 2/2 white Reflection creature token.",
				_mirror_if))
			c.activated(ActivatedAbility.new("{0}", false,
				[DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Reflection", _reflection))],
				"{0}: Destroy target Reflection."))
		"Staunch Defenders":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, M._gain_life.bind(4),
				"When this creature enters, you gain 4 life.", F._self_enter))
		"Unstable Shapeshifter":
			c.triggered(_shapeshift_ability())
		"Verdant Force":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _make_tokens.bind(F._saproling()),
				"At the beginning of each upkeep, create a 1/1 green Saproling creature token."))
		"Warmth":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, M._gain_life.bind(2),
				"Whenever an opponent casts a red spell, you gain 2 life.", _opponent_spell.bind(Mtg.ManaColor.R)))
		"Wild Wurm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _wild_wurm,
				"When this creature enters, flip a coin. If you lose the flip, return this creature to its owner's hand.",
				F._self_enter))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func _enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func _reflection(i: CardInstance) -> bool: return i.has_subtype("reflection")
static func _mountain(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("mountain")

## Was [param i] a creature — live on the battlefield, last known once it
## has left (CR 608.2h).
static func _was_creature(i: CardInstance) -> bool:
	if i.zone == Mtg.Zone.BATTLEFIELD: return i.is_creature()
	return (i.last_types & Mtg.CardType.CREATURE) != 0

## The creature a trigger captured under [param key], if it is still that
## object on the battlefield (CR 400.7).
static func _captured(g: MtgGame, s: CardInstance, key: String) -> CardInstance:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get(key, -1)))
	return i if g.is_present(i) and i.layer_timestamp == int(ctx.get(key + "_stamp", -2)) else null

## The victim of one damage event and how much it was dealt, captured as
## the ability triggers (WAS_DEALT_DAMAGE / DAMAGE_DEALT both name it
## `to_instance`).
static func _victim_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	ctx["amount"] = int(e.data.get("amount", 0))
	if hit != null:
		ctx["hit"] = hit.id
		ctx["hit_stamp"] = hit.layer_timestamp
		ctx["hit_controller"] = hit.controller_id
	return ctx

## "Put a <kind> counter on this creature" — only the same object.
static func _counter_on_self(g: MtgGame, s: CardInstance, _e: GameEvent, kind: String) -> void:
	if F._same_trigger_source(g, s):
		g.add_counters(s, kind)

static func _make_tokens(g: MtgGame, s: CardInstance, _e: GameEvent, effect: CreateTokenEffect) -> void:
	effect.resolve(g, s, M.pid_of(g, s), null)

static func _draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)

static func _destroy_targets(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if victim != null: g.destroy(victim)

## A targeted trigger's preference for a HARMFUL target: the other side's
## permanents first, the costliest first (an enchantment has no body).
static func _theirs_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.controller_acting_for(s)
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	var av := (1000 if ai.controller_id != me else 0) + ai.data.cost.mana_value()
	var bv := (1000 if bi.controller_id != me else 0) + bi.data.cost.mana_value()
	return av > bv

## "Sacrifice a creature" — the acting seat's own choice among its
## creatures, offered cheapest-to-lose first with [param keep] last.
static func _sacrifice_a_creature(g: MtgGame, s: CardInstance, keep: CardInstance, prompt: String) -> void:
	var pid := M.pid_of(g, s)
	var mine := M.creatures_of(g, pid, func(i: CardInstance) -> bool: return not i.phased_out)
	if mine.is_empty(): return
	M.least_valuable_first(mine, keep)
	g.sacrifice_permanent(M.pick(g, pid, mine, prompt))

static func _opponent_spell(g: MtgGame, s: CardInstance, e: GameEvent, color: int) -> bool:
	var caster := int(e.data.get("controller", -1))
	return caster >= 0 and caster != s.controller_id and M.spell_of(g, s, e, color)

static func _no_creatures_against(g: MtgGame, pid: int) -> bool:
	for i in g.players[g.opponent_of(pid)].battlefield:
		if i.is_creature() and g.is_present(i): return false
	return true

## Is there a permanent with [param subtype] on the battlefield (a token
## only when [param tokens_only])?
static func _any_on_battlefield(g: MtgGame, subtype: String, tokens_only := false) -> bool:
	for i in g.all_battlefield():
		if g.is_present(i) and i.has_subtype(subtype) and (i.is_token or not tokens_only):
			return true
	return false


# ------------------------------------------------------------- Ancient Runes --

## "That player": the upkeep's player; the artifacts are counted as the
## ability resolves (CR 608.2h), and the damage is the Runes' as it last
## existed if it has left (Black Vise's shape).
static func _runes(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var n := 0
	for i in g.players[who].battlefield:
		if i.is_type(Mtg.CardType.ARTIFACT) and g.is_present(i): n += 1
	if n > 0:
		g.deal_damage(s, TargetRef.player(who), n)


# --------------------------------------------------------- Angelic Protector --

static func _protector(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.continuous.add_until_eot_pump(s.id, 0, 3, [])
	g.log_line("%s gets +0/+3 until end of turn" % s.data.card_name, s)
	g.recalculate()


# ------------------------------------------------------------ Avenging Angel --

## "You" — the controller when it died (CR 603.3a); "its owner's library"
## — the card goes home whoever controlled it. Only the card that hit the
## graveyard, still there (CR 400.7).
static func _avenging_angel(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(ctx.get("entry", -1)): return
	var pid := M.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Put Avenging Angel on top of its owner's library?", true):
		g.return_from_graveyard_to_library_top(s)


# ----------------------------------------------------------- Bellowing Fiend --

## "Deals damage to a creature" — one trigger per damage packet, the pool's
## convention for "whenever this deals damage" (mir/_triggers.gd header).
static func _damages_a_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if e.data.get("source") != s or int(e.data.get("amount", 0)) <= 0: return false
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and _was_creature(hit)

## "That creature's controller": its controller now if it is still the
## same creature, else as it last existed. Both 3s are one damage event
## (the same player twice when the Fiend hit its own creature: 6).
static func _fiend(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var who := int(ctx.get("hit_controller", -1))
	var hit := _captured(g, s, "hit")
	if hit != null: who = hit.controller_id
	var me := M.pid_of(g, s)
	g.begin_simultaneous()
	if who >= 0: g.deal_damage(s, TargetRef.player(who), 3)
	g.deal_damage(s, TargetRef.player(me), 3)
	g.end_simultaneous()


# --------------------------------------------------------------- Chaotic Goo --

## "You may flip": nothing to gain once the Goo has gone. The hint flips
## while a lost flip still leaves a body (one counter at least remains).
static func _goo(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := M.pid_of(g, s)
	var n := int(s.counters.get("+1/+1", 0))
	if not g.agents[pid].choose_yes_no(g, pid,
			"Chaotic Goo: flip a coin? (Win: put a +1/+1 counter on it. Lose: remove one.)", n >= 2):
		return
	if g.flip_coin(pid):
		g.add_counters(s, "+1/+1")
	elif int(s.counters.get("+1/+1", 0)) > 0:
		g.remove_counters(s, "+1/+1", 1)


# --------------------------------------------------- Commander Greven il-Vec --

## Any creature its controller controls — Greven itself included, offered
## last (with no other creature it must go).
static func _greven(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	_sacrifice_a_creature(g, s, s, "Commander Greven il-Vec: sacrifice a creature")


# -------------------------------------------------------- Death Pits of Rath --

static func _creature_dealt_damage(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and int(e.data.get("amount", 0)) > 0 and _was_creature(hit)

static func _death_pits(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var hit := _captured(g, s, "hit")
	if hit != null:
		g.destroy(hit, false)


# ------------------------------------------------------------- Dirtcowl Wurm --

static func _opponent_played_land(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("controller", -1))
	return who >= 0 and who != s.controller_id


# ------------------------------------------------------------ Fugitive Druid --

## Only an AURA SPELL naming it — not an ability, not another spell.
static func _aura_spell_targets_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("source")
	return e.data.get("instance") == s and bool(e.data.get("is_spell", false)) \
		and spell != null and spell.is_aura()


# --------------------------------------------------------------------- Havoc --

## "They" — the player who cast the white spell.
static func _havoc(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0:
		g.adjust_life(who, -2)


# ---------------------------------------------------------------- Jackal Pup --

static func _dealt_damage_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("to_instance") == s and int(e.data.get("amount", 0)) > 0

## "It deals that much damage to you" — from the Pup as it last existed if
## the damage killed it; "you" is the seat that controlled the trigger.
static func _pup(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var amount := int(g.trigger_context(s).get("amount", 0))
	if amount > 0:
		g.deal_damage(s, TargetRef.player(M.pid_of(g, s)), amount)


# ---------------------------------------------------------------- Kezzerdrix --

static func _kezzerdrix_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and _no_creatures_against(g, s.controller_id)

## The intervening "if", rechecked on resolution (CR 603.4).
static func _kezzerdrix(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if _no_creatures_against(g, pid):
		g.deal_damage(s, TargetRef.player(pid), 4)


# ----------------------------------------------------------- Legacy's Allure --

static func _allure_counter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := M.pid_of(g, s)
	if g.agents[pid].choose_yes_no(g, pid, "Put a treasure counter on Legacy's Allure?", true):
		g.add_counters(s, "treasure")

## The treasure counters as the target is chosen (the Allure is still on the
## battlefield, CR 602.2b: targets before costs) and, once the sacrifice has
## paid for it, as it last existed (CR 608.2h) when the target is checked
## again on resolution.
static func _treasure(s: CardInstance) -> int:
	var counters: Dictionary = s.counters if s.zone == Mtg.Zone.BATTLEFIELD else s.last_counters
	return int(counters.get("treasure", 0))

static func _within_treasure(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.cur_power <= _treasure(s)

static func _allure_steal(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if g.is_present(i):
		g.change_control(i, pid)


# ----------------------------------------------------------------- Magmasaur --

## The controller may remove a counter (not a cost — an instruction). If
## not, the Magmasaur is sacrificed and deals damage equal to the +1/+1
## counters it had as it left (CR 608.2h) to each creature without flying
## and each player, one simultaneous event. A Magmasaur that has already
## left can have no counter removed: the damage is its last count, the
## Primordial Ooze convention (leg/primordial_ooze.gd). Phased out it is
## treated as though it doesn't exist (CR 702.26b): nothing happens.
static func _magmasaur(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var n := 0
	if F._same_trigger_object(g, s):
		if s.phased_out: return
		n = int(s.counters.get("+1/+1", 0))
		if n > 0 and g.agents[pid].choose_yes_no(g, pid,
				"Remove a +1/+1 counter from Magmasaur? (If you don't, sacrifice it and it deals %d damage to each creature without flying and each player.)" % n,
				n >= 2):
			g.remove_counters(s, "+1/+1", 1)
			return
		if s.controller_id == pid:
			g.sacrifice_permanent(s)
	else:
		n = int(s.last_counters.get("+1/+1", 0))
	if n <= 0: return
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature() and g.is_present(i) and not i.has_keyword(Mtg.Keyword.FLYING):
			victims.append(i)
	g.begin_simultaneous()
	for i in victims:
		g.deal_damage(s, TargetRef.card(i), n)
	for p in g.players.size():
		g.deal_damage(s, TargetRef.player(p), n)
	g.end_simultaneous()


# -------------------------------------------------------------- Mongrel Pack --

## "Dies during combat" — any step of the combat phase (CR 506).
static func _dies_during_combat(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and Mtg.is_combat_step(g.current_step())


# ------------------------------------------------------------- Orim's Prayer --

## "Attack you": the defending player is this enchantment's controller.
static func _attack_on_you(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return not (e.data.get("attackers", []) as Array).is_empty() \
		and g.opponent_of(g.active_player) == s.controller_id

## The attacking creatures are counted as the ability resolves (CR 608.2h).
static func _prayer(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var n := 0
	for id in g.combat.attackers:
		if g.is_present(g.find_instance(int(id))): n += 1
	if n > 0:
		g.adjust_life(M.pid_of(g, s), n)


# -------------------------------------------------------------- Rathi Dragon --

## "Sacrifice it unless you sacrifice two Mountains" — a payment made as the
## trigger resolves (MtgGame.unless_objects_paid, Ovinomancer's shape). The
## hint keeps the Dragon while two lands remain afterwards.
static func _rathi_dragon(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	if s.controller_id != pid: return
	var lands := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): lands += 1
	if g.unless_objects_paid(pid, s, [OC.sacrificing("Mountain", _mountain, 2)],
			"Rathi Dragon: sacrifice two Mountains? (otherwise sacrifice Rathi Dragon)", lands >= 4):
		return
	g.sacrifice_permanent(s)


# ------------------------------------------------------------------- Recycle --

## "Skip your draw step" — mandatory: no question, no draw, no priority in
## the step (CR 614.1b).
static func _recycle_skip(g: MtgGame, s: CardInstance, pid: int) -> bool:
	if pid != s.controller_id or not g.is_present(s): return false
	g.log_line("Recycle: %s skips their draw step" % g.players[pid].player_name, s)
	return true

## "Whenever you play a card": you cast a spell (SPELL_CAST) or play a land
## (LAND_PLAYED); both name the player as `controller`.
static func _you_played_a_card(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("controller", -1)) == s.controller_id

static func _hand_size_two(g: MtgGame, s: CardInstance) -> void:
	g.players[s.controller_id].max_hand_size = 2


# ---------------------------------------------------------------- Sarcomancy --

static func _sarcomancy_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and not _any_on_battlefield(g, "zombie")

static func _sarcomancy_bite(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not _any_on_battlefield(g, "zombie"):
		g.deal_damage(s, TargetRef.player(M.pid_of(g, s)), 1)


# -------------------------------------------------------- Servant of Volrath --

## "You" — the seat that controlled it as it left (CR 603.3a).
static func _servant(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	_sacrifice_a_creature(g, s, null, "Servant of Volrath: sacrifice a creature")


# ------------------------------------------------------------------- Shocker --

static func _damages_a_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and int(e.data.get("amount", 0)) > 0 and e.data.has("to_player")

## "That many": the cards actually in the hand it discards.
static func _shocker(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("to_player", -1))
	if who < 0: return
	var n := g.players[who].hand.size()
	g.discard_hand(who)
	if n > 0:
		g.draw_cards(who, n)


# ------------------------------------------------------------- Spirit Mirror --

static func _mirror_if(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and not _any_on_battlefield(g, "reflection", true)

static func _spirit_mirror(g: MtgGame, s: CardInstance, e: GameEvent, reflection: CreateTokenEffect) -> void:
	if not _any_on_battlefield(g, "reflection", true):
		_make_tokens(g, s, e, reflection)


# ----------------------------------------------------- Unstable Shapeshifter --

## The ability, built fresh each time so every copied definition carries its
## own instance of it (2ed/vesuvan_doppelganger.gd:_shift_ability).
static func _shapeshift_ability() -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _shapeshift,
		"Whenever another creature enters, this creature becomes a copy of that creature, except it has this ability.",
		_another_creature_enters).capturing(_entrant_context)

static func _another_creature_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i != s and i.is_creature()

## The creature that entered, and its copiable values as it entered — the
## last known ones if it has left before the ability resolves (CR 608.2h,
## 707.2; a face-down creature is a nameless 2/2, MtgGame.copiable_data).
static func _entrant_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var i: CardInstance = e.data.get("instance")
	ctx["entrant"] = i.id
	ctx["entrant_stamp"] = i.layer_timestamp
	ctx["entrant_data"] = g.copiable_data(i)
	return ctx

## Mandatory: no "may". Its colour is copied too (unlike Vesuvan
## Doppelganger); counters, damage and tapped state stay (CR 707.2).
static func _shapeshift(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var ctx := g.trigger_context(s)
	var shape: CardData = ctx.get("entrant_data")
	var i := g.find_instance(int(ctx.get("entrant", -1)))
	if g.is_present(i) and i.layer_timestamp == int(ctx.get("entrant_stamp", -2)):
		shape = g.copiable_data(i)
	if shape != null:
		g.become_copy(s, shape.with_extra_trigger(_shapeshift_ability()))


# ----------------------------------------------------------------- Wild Wurm --

static func _wild_wurm(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if g.flip_coin(M.pid_of(g, s)): return
	if F._same_trigger_source(g, s):
		g.return_to_hand(s)
