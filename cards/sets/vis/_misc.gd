extends RefCounted
## Visions (_misc, Pack 8). Everything else: world enchantments, global effects and one-off rules.
##
## Batch B7 — the replacement and global-rules suite, Visions half. Like
## the Mirage module (cards/sets/mir/_misc.gd) these are declarations over
## the Pack 8 engine packages: E5's damage replacement suite (Honorable
## Passage, Lichenthrope, Ogre Enforcer), E4's bans (City of Solitude,
## Peace Talks), E10's additive land type (Blanket of Night), E3/E7's flash
## rider and "becomes an Aura" (Necromancy). The triggered abilities act
## for the seat that controlled them when they triggered (CR 603.3a).
const F := preload("res://cards/sets/fem/_rules.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Eye of Singularity":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _eye_sweep,
				"When this enchantment enters, destroy each permanent with the same name as another permanent, except for basic lands. They can't be regenerated.",
				F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _eye_newcomer,
				"Whenever a permanent other than a basic land enters, destroy all other permanents with that name. They can't be regenerated.",
				_named_nonbasic_entered).capturing(_newcomer_context))
		"Honorable Passage":
			c.spell(SourceShieldEffect.prevent_to_target().with_rider(_red_rider))
		"Peace Talks":
			c.spell(F.Action.new(_peace_talks,
				"this turn and next turn, creatures can't attack, and players and permanents can't be the targets of spells or activated abilities"))
		"Righteous Aura":
			c.activated(ActivatedAbility.new("{W}", false,
				[PreventDamageShieldEffect.new(0).from_sources("a source", _any)],
				"{W}, Pay 2 life: The next time a source of your choice would deal damage to you this turn, prevent that damage.")
				.with_life_cost(2))
		"Blanket of Night":
			c.static_ability(StaticAbility.new(_swamps,
				"Each land is a Swamp in addition to its other land types.").changing_land_types())
		"Necromancy":
			c.with_flash_rider()
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _necromancy,
				"When this enchantment enters, if it's on the battlefield, it becomes an Aura with \"enchant creature put onto the battlefield with Necromancy.\" Put target creature card from a graveyard onto the battlefield under your control and attach this enchantment to it. When this enchantment leaves the battlefield, that creature's controller sacrifices it.",
				_entered_and_present).targeting(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD),
				_best_corpse_first, "Necromancy: choose target creature card in a graveyard"))
		"Pillar Tombs of Aku":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _pillar_tombs,
				"At the beginning of each player's upkeep, that player may sacrifice a creature of their choice. If that player doesn't, they lose 5 life and you sacrifice this enchantment."))
		"Elkin Lair":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _elkin_lair,
				"At the beginning of each player's upkeep, that player exiles a card at random from their hand. The player may play that card this turn. At the beginning of the next end step, if the player hasn't played the card, they put it into their graveyard."))
		"Ogre Enforcer":
			c.with_lethal_needs_single_source()
		"City of Solitude":
			c.bans_activations(_solitude_activation)
			c.bans_playing(_solitude_cast)
		"Lichenthrope":
			c.static_ability(StaticAbility.new(_lichen_counters,
				"If damage would be dealt to this creature, put that many -1/-1 counters on it instead."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _lichen_heal,
				"At the beginning of your upkeep, remove a -1/-1 counter from this creature.", F._your_upkeep))
		"Breathstealer's Crypt":
			c.replaces_draws(_breathstealer_draw, _breathstealer_applies)
		"Righteous War":
			c.static_ability(StaticAbility.new(_righteous_war,
				"White creatures you control have protection from black. Black creatures you control have protection from white.").changing_abilities())
		_: return false
	return true


# ------------------------------------------------------------- shared --

## The seat a resolving trigger acts for (CR 603.3a).
static func _pid(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id


static func _any(_inst: CardInstance) -> bool:
	return true


## A basic land on the battlefield (live supertypes, CR 205.4).
static func _is_basic_land(inst: CardInstance) -> bool:
	return inst.is_land() and (inst.cur_supertypes & Mtg.Supertype.BASIC) != 0


# ------------------------------------------------------ Eye of Singularity --

## Every permanent sharing its name with another one, basic lands aside,
## destroyed at once (one bracket) and without regeneration. A face-down
## permanent has no name (CR 708.2) and so shares none.
static func _eye_sweep(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var by_name := {}
	for perm in g.all_battlefield():
		if perm.face_down or _is_basic_land(perm):
			continue
		var n := perm.data.card_name
		if not by_name.has(n):
			by_name[n] = []
		by_name[n].append(perm)
	var doomed: Array[CardInstance] = []
	for n in by_name:
		if (by_name[n] as Array).size() >= 2:
			for perm in by_name[n]:
				doomed.append(perm)
	_destroy_all(g, doomed)


static func _named_nonbasic_entered(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var inst: CardInstance = e.data.get("instance")
	return inst != null and not inst.face_down and not _is_basic_land(inst)


## The newcomer's name and identity, as it entered — it may be gone by the
## time the trigger resolves; "all other permanents with that name" still
## means everything but that object.
static func _newcomer_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var inst: CardInstance = e.data.get("instance")
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"name": inst.data.card_name, "id": inst.id, "stamp": inst.layer_timestamp}


static func _eye_newcomer(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var n := String(ctx.get("name", ""))
	var doomed: Array[CardInstance] = []
	for perm in g.all_battlefield():
		if perm.face_down or perm.data.card_name != n:
			continue
		if perm.id == int(ctx.get("id", -1)) and perm.layer_timestamp == int(ctx.get("stamp", -1)):
			continue
		doomed.append(perm)
	_destroy_all(g, doomed)


static func _destroy_all(g: MtgGame, doomed: Array[CardInstance]) -> void:
	if doomed.is_empty():
		return
	g.begin_simultaneous()
	for perm in doomed:
		if perm.zone == Mtg.Zone.BATTLEFIELD:
			g.destroy(perm, false)
	g.end_simultaneous()


# ------------------------------------------------------ Honorable Passage --

## "If damage from a red source is prevented this way, Honorable Passage
## deals that much damage to the source's controller." The Passage (the
## effect's source, in a graveyard by now) deals it, as it last existed.
static func _red_rider(g: MtgGame, packet: DamagePacket, amount: int,
		passage: CardInstance, _pid: int) -> void:
	if (g.damage_source_colors(packet.source) & Mtg.ManaColor.R) != 0 and amount > 0:
		g.deal_damage(passage, TargetRef.player(packet.source.controller_id), amount)


# ------------------------------------------------------------ Peace Talks --

## "This turn and next turn": a floating static for the rest of this turn,
## and the same static queued for the start of the next turn — whoever's
## it is (an extra turn first, CR 500.7).
static func _peace_talks(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var peace := StaticAbility.new(_peace, "Creatures can't attack, and players and permanents can't be the targets of spells or activated abilities.")
	g.continuous.add_floating_static(s, peace)
	var next_pid: int = g.extra_turns[0] if not g.extra_turns.is_empty() else g.opponent_of(g.active_player)
	g.queue_next_turn_static(next_pid, s, peace)
	g.recalculate()
	g.log_line("Peace Talks: no attacks and no spell or ability targets this turn and next turn")


static func _peace(g: MtgGame, _s: CardInstance) -> void:
	for p in g.players:
		p.cur_target_bans.append({"desc": "Peace Talks", "filter": _not_a_trigger})
	for inst in g.all_battlefield():
		inst.cur_target_bans.append({"desc": "Peace Talks", "filter": _not_a_trigger})
		if inst.is_creature():
			inst.cur_cant_attack = true


## Spells and ACTIVATED abilities are refused; a triggered ability may
## still target (E4's targeting_kind).
static func _not_a_trigger(g: MtgGame, source: CardInstance, spec: TargetSpec) -> bool:
	return g.targeting_kind(source, spec) != Mtg.StackKind.TRIGGER


# ------------------------------------------------------- Blanket of Night --

static func _swamps(g: MtgGame, _s: CardInstance) -> void:
	for land in g.all_battlefield():
		if land.is_land():
			land.add_basic_land_type("swamp")


# -------------------------------------------------------------- Necromancy --

static func _entered_and_present(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and s.zone == Mtg.Zone.BATTLEFIELD


## The intervening "if it's on the battlefield" (CR 603.4) is checked again
## here; the creature card enters under the Necromancy's controller and the
## enchantment becomes its Aura (E7's reanimate_as_aura). A target gone by
## now fizzles the trigger before this runs.
static func _necromancy(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null:
		return
	var card := g.find_instance(int(targets[0].instance_id))
	if card == null or card.zone != Mtg.Zone.GRAVEYARD:
		return
	g.reanimate_as_aura(s, card, _pid(g, s))


## The best body first (public graveyards): power + toughness, then mana value.
static func _best_corpse_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null:
		return ai != null
	var av := ai.data.power + ai.data.toughness
	var bv := bi.data.power + bi.data.toughness
	if av != bv:
		return av > bv
	return ai.data.cost.mana_value() > bi.data.cost.mana_value()


# ---------------------------------------------------- Pillar Tombs of Aku --

## "That player may sacrifice a creature of their choice. If that player
## doesn't, they lose 5 life and you sacrifice this enchantment." The
## player whose upkeep it is decides; "you" is the Tombs' controller, who
## sacrifices it only while it is the same object under their control.
static func _pillar_tombs(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", g.active_player))
	var mine := _pid(g, s)
	var bodies: Array[CardInstance] = g.players[who].creatures()
	bodies.sort_custom(_cheaper_creature)
	if not bodies.is_empty():
		var weakest: CardInstance = bodies[0]
		var hint: bool = g.players[who].life <= 5 or weakest.is_token or weakest.cur_power <= 1
		if g.agents[who].choose_yes_no(g, who,
				"Pillar Tombs of Aku: sacrifice a creature? (If you don't, you lose 5 life and the Tombs are sacrificed.)", hint):
			var pick := g.agents[who].choose_card(g, who, bodies,
				"Pillar Tombs of Aku: choose a creature to sacrifice", false, false, true)
			if pick == null or not bodies.has(pick):
				pick = bodies[0]
			g.sacrifice_permanent(pick)
			return
	g.adjust_life(who, -5)
	g.log_line("%s sacrifices no creature to Pillar Tombs of Aku" % g.players[who].player_name)
	if F._same_trigger_source(g, s) and s.controller_id == mine:
		g.sacrifice_permanent(s)


static func _cheaper_creature(a: CardInstance, b: CardInstance) -> bool:
	if a.is_token != b.is_token:
		return a.is_token
	var av := a.cur_power + a.cur_toughness
	var bv := b.cur_power + b.cur_toughness
	if av != bv:
		return av < bv
	return a.id < b.id


# -------------------------------------------------------------- Elkin Lair --

## A card at random (game.rng — CONTRIBUTING rule 7) exiled face up from
## the hand of the player whose upkeep it is; that player may play it this
## turn; at the beginning of the next end step, if it is still that same
## exiled card, it goes to its owner's graveyard (and the permission with
## it).
static func _elkin_lair(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", g.active_player))
	var hand: Array[CardInstance] = g.players[who].hand
	if hand.is_empty():
		return
	var card: CardInstance = hand[g.rng.randi_range(0, hand.size() - 1)]
	g.exile_from_hand(card)
	if card.zone != Mtg.Zone.EXILE:
		return
	g.grant_exile_play(card, who)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		_lair_bury.bind(card.id, card.exile_entry),
		"At the beginning of the next end step, if the player hasn't played the card, they put it into their graveyard."),
		_pid(g, s), s, false, {}, "Elkin Lair: %s goes to the graveyard unless played this turn" % card.data.card_name)


static func _lair_bury(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, entry: int) -> void:
	var card := g.find_instance(id)
	if card == null or card.zone != Mtg.Zone.EXILE or card.exile_entry != entry:
		return   # played (or otherwise moved) — nothing to bury
	g.return_from_exile_to_graveyard(card)


# -------------------------------------------------------- City of Solitude --

## "Players can cast spells and activate abilities only during their own
## turns" — mana abilities too (CR 605.1a). Lands are not cast.
static func _solitude_activation(g: MtgGame, _s: CardInstance, pid: int, _inst: CardInstance,
		_ability: Variant, _is_mana: bool) -> bool:
	return pid != g.active_player


## A play ban's callback is not told which permanent radiates it, so the
## "live" rule E4 gives activation bans (a phased-out or silenced source
## bans nothing) is checked here by looking for a City that still has its
## ability.
static func _solitude_cast(g: MtgGame, pid: int, data: CardData) -> bool:
	if pid == g.active_player or data.is_land():
		return false
	for inst in g.all_battlefield():
		if inst.data.card_name == "City of Solitude" and not inst.phased_out \
				and not inst.cur_abilities_silenced:
			return true
	return false


# ------------------------------------------------------------ Lichenthrope --

static func _lichen_counters(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"counters", "counter": "-1/-1", "victims": [s],
		"desc": "Lichenthrope: damage becomes -1/-1 counters"})


static func _lichen_heal(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and int(s.counters.get("-1/-1", 0)) > 0:
		g.remove_counters(s, "-1/-1", 1)


# --------------------------------------------------- Breathstealer's Crypt --

static func _breathstealer_applies(_g: MtgGame, s: CardInstance, _pid: int, _ctx: Dictionary) -> bool:
	return not s.cur_abilities_silenced and not s.phased_out


## "Instead they draw a card and reveal it. If it's a creature card, that
## player discards it unless they pay 3 life." The draw inside is a new
## event the Crypt does not apply to again (CR 614.5, the engine's re-entry
## guard); another replacement may (Forbidden Crypt) — then no card was
## drawn and nothing is revealed. Life can be paid only while the player
## has at least 3 (CR 119.4).
static func _breathstealer_draw(g: MtgGame, s: CardInstance, pid: int, ctx: Dictionary) -> bool:
	if not _breathstealer_applies(g, s, pid, ctx):
		return false
	var p := g.players[pid]
	# The card the draw would take is the library's top; it counts as DRAWN
	# only if it is what reached the hand (a card returned instead by
	# another replacement is not "it").
	var top: CardInstance = p.library.back() if not p.library.is_empty() else null
	g.draw_cards(pid, 1)
	var drawn: CardInstance = top if top != null and top.zone == Mtg.Zone.HAND else null
	if drawn == null:
		return true
	g.log_line("%s reveals %s (Breathstealer's Crypt)" % [p.player_name, drawn.data.card_name], drawn)
	g.reveal_information(g.opponent_of(pid), "Breathstealer's Crypt", [drawn.data.card_name])
	if not drawn.is_creature():
		return true
	if p.life >= 3 and g.agents[pid].choose_yes_no(g, pid,
			"Breathstealer's Crypt: pay 3 life to keep %s? (Otherwise discard it.)" % drawn.data.card_name,
			p.life > 8):
		g.adjust_life(pid, -3)
		g.log_line("%s pays 3 life to keep %s" % [p.player_name, drawn.data.card_name])
		return true
	if drawn.zone == Mtg.Zone.HAND:
		g.discard_cards(pid, [drawn])
	return true


# ----------------------------------------------------------- Righteous War --

## Layer 6, after layer 5 settled the colours: a white-and-black creature
## gets both.
static func _righteous_war(g: MtgGame, s: CardInstance) -> void:
	for inst in g.players[s.controller_id].battlefield:
		if not inst.is_creature():
			continue
		if (inst.cur_colors & Mtg.ManaColor.W) != 0:
			inst.cur_protection |= Mtg.ManaColor.B
		if (inst.cur_colors & Mtg.ManaColor.B) != 0:
			inst.cur_protection |= Mtg.ManaColor.W
