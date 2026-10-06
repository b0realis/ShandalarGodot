extends RefCounted
## Tempest (_artifacts, Pack 9). Noncreature artifacts and their activated or static abilities.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the shared vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape. tests/cards/test_pack_9_B7_artifacts.gd pins each
## card's distinguishing clause and its edges.
##
## Altar of Dementia — the sacrificed creature's power is last known
##   information recorded with the cost (`_sacrificed_power`, CR 608.2h);
##   a negative power mills nothing.
## Booby Trap — both choices are made as it enters (CR 614.1c): the
##   opponent (MtgGame.choose_opponent, asked even at a two-seat table) and
##   a name from THAT player's decklist, basic land names left out (the
##   owner's ruling of 2026-09-07, docs/simplified-cards.md "Naming a card,
##   rewriting a card" — not a deviation; Nebuchadnezzar's `nameable`
##   order: most copies still unaccounted for in public zones first). "Reveals each card they draw" is a STATIC
##   ability — no stack object, Rowen's shape (as_mana_trigger) — so under
##   the 1997 rule a tapped Trap stops revealing (cur_statics_suspended);
##   the draw trigger is a triggered ability and keeps working.
## Cold Storage — the link to what it exiled (CR 607.2a) is kept on each
##   exiled card ([id, timestamp] of the Storage and the card's own
##   exile_entry), because the Storage's sacrifice is a COST: its memory is
##   wiped (CR 400.7) before the ability resolves. Only creature CARDS come
##   back (a token ceased to exist in exile, an animated land is a land
##   card), under the activating player's control.
## Cursed Scroll — "any target" is chosen as it is activated; the name on
##   resolution, from the activator's own decklist (Petra Sphinx's rule)
##   with the names in their own hand first, most copies first (their own
##   hand is theirs to know); the card is revealed at random on the game's
##   seeded RNG (RandomEffects.sample). An empty hand reveals nothing.
## Echo Chamber — "an opponent chooses target creature they control" is
##   TargetSpec.opponent_chooses (the opponent's order: their weakest body
##   first); the copy is MtgGame.copiable_data (a face-down creature copies
##   as a 2/2), haste until end of turn, and a delayed END_STEP trigger
##   (CR 603.7) exiles that token if it is still the same object.
##   AI role `hasty_token` (Balduvian Dead's reading: a main-1 attacker),
##   parameter `opponent_chooses` (the copy is the body they name).
## Essence Bottle / Torture Chamber — "Remove all <kind> counters" is a cost
##   (CR 118.3, 602.2b): ActivatedAbility.on_cost_paid removes them as the
##   ability is activated and records how many (`_counters_removed`), so a
##   second activation in response finds none.
## Flowstone Sculpture — the choice is made on resolution (CR 608.2d); the
##   keyword is granted with no duration (MtgGame.grant_keyword_permanently,
##   CR 611.2).
## Grindstone — the loop stops when fewer than two cards were milled (an
##   empty library) or the two share no colour (colourless shares none);
##   "milled this way" counts a card only if it reached the graveyard.
## Helm of Possession — "you may choose not to untap" plus Rubinia's leash
##   (gain_control_leashed, needs_tapped): it lasts while the activating
##   player controls this same Helm and it has stayed tapped since the
##   activation; if that has already ended on resolution, nothing happens
##   (CR 611.2b).
## Jinxed Idol — the upkeep damage hits whoever controlled it as the
##   trigger triggered; the gift is MtgGame.change_control of the Idol
##   itself, if it is still the object that was activated.
## Mogg Cannon — the pump (+1/+0 and flying) and an end-step destruction
##   (MtgGame.doom_at_next_end_step; regeneration applies — "destroy").
## Puppet Strings — "you may tap or untap": three answers, the third leaves
##   it as it is (CR 608.2d).
## Scalding Tongs / Thumbscrews — intervening-if upkeep triggers (CR 603.4:
##   the hand size is checked as they trigger and again on resolution) that
##   target an opponent (no planeswalkers in this pool).
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const WC := preload("res://cards/sets/wth/_creatures.gd")
const NEB := preload("res://cards/sets/leg/nebuchadnezzar.gd")
const PATH := "res://cards/sets/tmp/_artifacts.gd"

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Altar of Dementia":
			c.activated(ActivatedAbility.new("", false, [Dementia.new().with_ai_role(&"sacrifice_mill")],
				"Sacrifice a creature: Target player mills cards equal to the sacrificed creature's power.") \
				.with_sacrifice_of("creature", _creature))
		"Booby Trap":
			c.as_it_enters(_trap_choose)
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DRAWN, _trap_reveal,
				"The chosen player reveals each card they draw.", _trap_reveals).as_mana_trigger())
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DRAWN, _trap_spring,
				"When the chosen player draws a card with the chosen name, sacrifice this artifact. If you do, this artifact deals 10 damage to that player.",
				_trap_hit))
		"Bottle Gnomes":
			# No {T}: usable the turn it arrives (CR 302.6).
			c.activated(ActivatedAbility.new("", false, [GainLifeEffect.new(3)],
				"Sacrifice this creature: You gain 3 life.").with_sacrifice_cost())
		"Cold Storage":
			c.activated(ActivatedAbility.new("{3}", false,
				[Store.new(TargetSpec.creature("target creature you control").with_source_filter(F._own).because("controller")) \
					.with_ai_role(&"stash_own_creature")],
				"{3}: Exile target creature you control."))
			c.activated(ActivatedAbility.new("", false, [Thaw.new().with_ai_role(&"release_stash")],
				"Sacrifice this artifact: Return each creature card exiled with this artifact to the battlefield under your control.") \
				.with_sacrifice_cost())
		"Cursed Scroll":
			c.activated(ActivatedAbility.new("{3}", true, [Scroll.new()],
				"{3}, {T}: Choose a card name, then reveal a card at random from your hand. If that card has the chosen name, this artifact deals 2 damage to any target."))
		"Echo Chamber":
			var theirs := TargetSpec.creature("target creature an opponent controls").with_source_filter(_not_yours).because("controller")
			theirs.opponent_chooses(_weakest_first, "Select target creature you control.")
			c.activated(ActivatedAbility.new("{4}", true, [Echo.new(theirs)],
				"{4}, {T}: An opponent chooses target creature they control. Create a token that's a copy of that creature. That token gains haste until end of turn. Exile the token at the beginning of the next end step. Activate only as a sorcery.") \
				.only_if(MA.sorcery_speed))
		"Emmessi Tome":
			c.activated(ActivatedAbility.new("{5}", true, [Rummage.new()],
				"{5}, {T}: Draw two cards, then discard a card."))
		"Energizer":
			c.activated(ActivatedAbility.new("{2}", true, [WC.SelfCounter.new("+1/+1")],
				"{2}, {T}: Put a +1/+1 counter on this creature."))
		"Essence Bottle":
			c.activated(ActivatedAbility.new("{3}", true, [Mark.new("elixir").with_ai_role(&"charge_counter", {"kind": "elixir"})],
				"{3}, {T}: Put an elixir counter on this artifact."))
			var drink := ActivatedAbility.new("", true, [Elixir.new().with_ai_role(&"cash_counters_life", {"kind": "elixir", "per": 2})],
				"{T}, Remove all elixir counters from this artifact: You gain 2 life for each elixir counter removed this way.")
			drink.on_cost_paid = _remove_all.bind("elixir")
			c.activated(drink)
		"Excavator":
			c.activated(ActivatedAbility.new("", true, [Excavate.new()],
				"{T}, Sacrifice a basic land: Target creature gains landwalk of each of the land types of the sacrificed land until end of turn.") \
				.with_sacrifice_of("basic land", _basic_land))
		"Flowstone Sculpture":
			c.activated(ActivatedAbility.new("{2}", false, [Sculpt.new()],
				"{2}, Discard a card: Put a +1/+1 counter on this creature or this creature gains flying, first strike, or trample.") \
				.with_discard_cost(1))
		"Fool's Tome":
			c.activated(ActivatedAbility.new("{2}", true, [DrawEffect.new(1)],
				"{2}, {T}: Draw a card. Activate only if you have no cards in hand.").only_if(_empty_hand))
		"Grindstone":
			c.activated(ActivatedAbility.new("{3}", true, [Grind.new()],
				"{3}, {T}: Target player mills two cards. If two cards that share a color were milled this way, repeat this process."))
		"Helm of Possession":
			c.with_may_skip_untap()
			c.activated(ActivatedAbility.new("{2}", true, [Possess.new().with_ai_role(&"steal_while_tapped")],
				"{2}, {T}, Sacrifice a creature: Gain control of target creature for as long as you control this artifact and this artifact remains tapped.") \
				.with_sacrifice_of("creature", _creature))
		"Jinxed Idol":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _idol_bite,
				"At the beginning of your upkeep, this artifact deals 2 damage to you.", F._your_upkeep))
			c.activated(ActivatedAbility.new("", false, [Jinx.new().with_ai_role(&"donate_self")],
				"Sacrifice a creature: Target opponent gains control of this artifact.") \
				.with_sacrifice_of("creature", _creature))
		"Mogg Cannon":
			c.activated(ActivatedAbility.new("", true, [Cannon.new()],
				"{T}: Target creature you control gets +1/+0 and gains flying until end of turn. Destroy that creature at the beginning of the next end step."))
		"Patchwork Gnomes":
			c.activated(ActivatedAbility.new("", false, [RegenerateEffect.new()],
				"Discard a card: Regenerate this creature.").with_discard_cost(1))
		"Puppet Strings":
			c.activated(ActivatedAbility.new("{2}", true, [Strings.new()],
				"{2}, {T}: You may tap or untap target creature."))
		"Scalding Tongs":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _tongs.bind(3, true),
				"At the beginning of your upkeep, if you have three or fewer cards in hand, this artifact deals 1 damage to target opponent or planeswalker.",
				_tongs_due.bind(3, true)).targeting(TargetSpec.opponent(), Callable(), "Select target opponent."))
		"Squee's Toy":
			c.activated(ActivatedAbility.new("", true, [PreventDamageEffect.new(1).target_creature()],
				"{T}: Prevent the next 1 damage that would be dealt to target creature this turn."))
		"Telethopter":
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff()],
				"Tap an untapped creature you control: This creature gains flying until end of turn.") \
				.with_object_cost(OC.tapping("an untapped creature you control", _creature)))
		"Thumbscrews":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _tongs.bind(5, false),
				"At the beginning of your upkeep, if you have five or more cards in hand, this artifact deals 1 damage to target opponent or planeswalker.",
				_tongs_due.bind(5, false)).targeting(TargetSpec.opponent(), Callable(), "Select target opponent."))
		"Torture Chamber":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._counter_upkeep.bind("pain"),
				"At the beginning of your upkeep, put a pain counter on this artifact.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _chamber_pain,
				"At the beginning of your end step, this artifact deals damage to you equal to the number of pain counters on it.",
				_your_end_step))
			var rack := ActivatedAbility.new("{1}", true, [Rack.new().with_ai_role(&"cash_counters_damage", {"kind": "pain"})],
				"{1}, {T}, Remove all pain counters from this artifact: It deals damage to target creature equal to the number of pain counters removed this way.")
			rack.on_cost_paid = _remove_all.bind("pain")
			c.activated(rack)
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func _creature(i: CardInstance) -> bool: return i.is_creature()

static func _basic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0

static func _not_yours(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id != s.controller_id

static func _your_end_step(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == s.controller_id

## The resolving ability's source is still the object that was activated.
static func _same(g: MtgGame, s: CardInstance) -> bool:
	return F._same_activation_source(g, s)

## "Remove all <kind> counters from this artifact" — paid with the rest of
## the cost (CR 602.2b); how many is what the effect reads.
static func _remove_all(g: MtgGame, s: CardInstance, paid: Dictionary, kind: String) -> void:
	var n := int(s.counters.get(kind, 0))
	paid["_counters_removed"] = n
	if n > 0: g.remove_counters(s, kind, n)

## A card name nobody can draw or reveal: the choice when nothing is nameable.
const NO_NAME := ""


# --------------------------------------------------------- Altar of Dementia --

class Dementia extends MillEffect:
	func _init() -> void:
		super(0)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var n := maxi(0, int(g.cost_paid("_sacrificed_power", 0)))
		if n > 0: g.mill(t.player_id if t != null and t.is_player else pid, n)
	func describe() -> String:
		return "target player mills cards equal to the sacrificed creature's power"


# --------------------------------------------------------------- Booby Trap --

## The names [param victim]'s decklist offers, basic land names left out.
static func trap_names(g: MtgGame, victim: int) -> Array[String]:
	var out: Array[String] = []
	for n in NEB.NameEffect.nameable(g, victim):
		var data := CardRegistry.get_card(n)
		if data != null and data.is_land() and (data.supertypes & Mtg.Supertype.BASIC) != 0:
			continue
		out.append(n)
	return out

static func _trap_choose(g: MtgGame, s: CardInstance, pid: int) -> void:
	var victim := g.choose_opponent(pid, s)
	var names := trap_names(g, victim)
	var named := NO_NAME
	if not names.is_empty():
		var picked: int = g.agents[pid].choose_option(g, pid, names,
			"Booby Trap: choose a card name (%s's decklist)" % g.players[victim].player_name, 0)
		named = names[clampi(picked, 0, names.size() - 1)]
	g._rec(s, &"memory")
	s.memory["victim"] = victim
	s.memory["named"] = named
	# The choice is announced (public), so both seats are shown it.
	if named != NO_NAME:
		g.reveal_information(-1, "%s names (for %s)" % [s.data.card_name, g.players[victim].player_name], [named])
	g.log_line("%s: %s names %s" % [s.data.card_name, g.players[pid].player_name,
		named if named != NO_NAME else "nothing"])

static func _trap_victim(g: MtgGame, s: CardInstance) -> int:
	return int(s.memory.get("victim", g.opponent_of(s.controller_id)))

## The static reveal: off while the 1997 rule has a tapped Trap stopped.
static func _trap_reveals(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == _trap_victim(g, s) and e.data.get("instance") != null \
		and not s.cur_statics_suspended and not s.cur_abilities_silenced

static func _trap_reveal(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var card: CardInstance = e.data.get("instance")
	var who := int(e.data.get("player", -1))
	g.reveal_information(-1, "%s: %s draws" % [s.data.card_name, g.players[who].player_name], [card.data.card_name])
	g.log_line("%s reveals %s (%s)" % [g.players[who].player_name, card.data.card_name, s.data.card_name])

static func _trap_hit(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var card: CardInstance = e.data.get("instance")
	var named := String(s.memory.get("named", NO_NAME))
	return named != NO_NAME and card != null and int(e.data.get("player", -1)) == _trap_victim(g, s) \
		and card.data.card_name == named

## "Sacrifice this artifact. If you do, ..." — only its controller as it
## triggered can sacrifice it, and only the object that triggered.
static func _trap_spring(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if not F._trigger_source_present(g, s): return
	var who := int(e.data.get("player", -1))
	g.sacrifice_permanent(s)
	if g.is_present(s) or who < 0: return
	g.deal_damage(s, TargetRef.player(who), 10)


# ------------------------------------------------------------- Cold Storage --

class Store extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
		g.exile_permanent(i)
		if i.zone != Mtg.Zone.EXILE or i.is_token: return
		g._rec(i, &"memory")
		i.memory["cold_storage"] = [s.id, stamp, i.exile_entry]
	func describe() -> String:
		return "exile target creature you control"

class Thaw extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var stamp := int(g.cost_paid("_source_timestamp", -1))
		var back: Array[CardInstance] = []
		for p in g.players:
			for card in p.exile:
				var link: Array = card.memory.get("cold_storage", [])
				if link.size() == 3 and int(link[0]) == s.id and int(link[1]) == stamp \
						and int(link[2]) == card.exile_entry and card.data.is_creature():
					back.append(card)
		for card in back:
			g._rec(card, &"memory")
			card.memory.erase("cold_storage")
			g.return_from_exile_to_play(card, pid)
	func describe() -> String:
		return "return each creature card exiled with this artifact to the battlefield under your control"


# ------------------------------------------------------------ Cursed Scroll --

## The names [param pid] may choose: their own decklist, each once, the
## names in their own hand first (most copies first), then alphabetical.
static func scroll_names(g: MtgGame, pid: int) -> Array[String]:
	var held := {}
	for card in g.players[pid].hand:
		held[card.data.card_name] = int(held.get(card.data.card_name, 0)) + 1
	var seen := {}
	var names: Array[String] = []
	for list in [g.players[pid].deck_names, held.keys()]:
		for n in list:
			if seen.has(n): continue
			seen[n] = true
			names.append(String(n))
	names.sort_custom(func(a: String, b: String) -> bool:
		if int(held.get(a, 0)) != int(held.get(b, 0)):
			return int(held.get(a, 0)) > int(held.get(b, 0))
		return a < b)
	return names

class Scroll extends DamageEffect:
	func _init() -> void:
		super(2)
		any_target()
		# The fair AI's reading (engine/ai/tempest_tactics.gd): the damage
		# lands only when the random card matches the name.
		ai_role = &"named_reveal_damage"
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var hand: Array = g.players[pid].hand
		if hand.is_empty():
			g.log_line("%s: %s has no card to reveal" % [s.data.card_name, g.players[pid].player_name])
			return
		var module: GDScript = load(PATH)
		var names: Array[String] = module.scroll_names(g, pid)
		var picked: int = g.agents[pid].choose_option(g, pid, names, "Cursed Scroll: choose a card name", 0)
		var named: String = names[clampi(picked, 0, names.size() - 1)]
		var shown: CardInstance = RandomEffects.sample(g, hand, 1)[0]
		g.reveal_information(-1, "Cursed Scroll: %s names %s and reveals" % [g.players[pid].player_name, named],
			[shown.data.card_name])
		g.log_line("%s names %s; %s reveals %s at random" % [g.players[pid].player_name, named,
			s.data.card_name, shown.data.card_name])
		if shown.data.card_name == named:
			super(g, s, pid, t, x)
	func describe() -> String:
		return "name a card and reveal one at random from your hand; if it matches, 2 damage to any target"


# ------------------------------------------------------------- Echo Chamber --

## The CHOOSER's order (the opponent's point of view): the body they would
## miss least first.
static func _weakest_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness + ia.data.cost.mana_value()
	var vb := ib.cur_power + ib.cur_toughness + ib.data.cost.mana_value()
	if va != vb: return va < vb
	return ia.id < ib.id

class Echo extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		with_ai_role(&"hasty_token", {"opponent_chooses": true})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var model := g.find_instance(t.instance_id)
		if not g.is_present(model): return
		var made := g.create_token(pid, g.copiable_data(model))
		if made.is_empty(): return
		var token := made[0]
		g.continuous.add_until_eot_keywords(token.id, [Mtg.Keyword.HASTE])
		g.recalculate()
		var module: GDScript = load(PATH)
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, module._echo_fade,
			"Exile the token at the beginning of the next end step."), pid, s, false,
			{"token": token.id, "stamp": token.layer_timestamp})
	func describe() -> String:
		return "create a hasty token copy of a creature an opponent chooses; exile it at the next end step"

static func _echo_fade(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var token := g.find_instance(int(memory.get("token", -1)))
	if g.is_present(token) and token.layer_timestamp == int(memory.get("stamp", -2)):
		g.exile_permanent(token)


# ------------------------------------------------------------- Emmessi Tome --

class Rummage extends DrawEffect:
	func _init() -> void:
		super(2)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		if g.players[pid].hand.is_empty(): return
		var thrown := g.agents[pid].choose_discard(g, pid, 1)
		if thrown.is_empty(): thrown = [g.players[pid].hand[-1]]
		g.discard_cards(pid, thrown)
	func describe() -> String:
		return "draw two cards, then discard a card"


# ------------------------------------------- Essence Bottle / Torture Chamber --

class Mark extends EffectBase:
	var kind: String
	func _init(counter_kind: String) -> void:
		kind = counter_kind
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s): g.add_counters(s, kind)
	func describe() -> String:
		return "put an %s counter on this artifact" % kind

class Elixir extends GainLifeEffect:
	func _init() -> void:
		super(0)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var n := int(g.cost_paid("_counters_removed", 0))
		if n > 0: g.adjust_life(pid, 2 * n)
	func describe() -> String:
		return "you gain 2 life for each elixir counter removed this way"

## "It deals damage" — the Chamber, by last known information if it has
## left (CR 608.2h), to the creature it targeted.
class Rack extends DamageEffect:
	func _init() -> void:
		super(0)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var n := int(g.cost_paid("_counters_removed", 0))
		if n > 0: g.deal_damage(s, t, n)
	func describe() -> String:
		return "deals damage to target creature equal to the number of pain counters removed this way"

## "Deals damage to you equal to the number of pain counters on it" — the
## count as it resolves, its last known count if it has left (CR 608.2h).
static func _chamber_pain(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var counters: Dictionary = s.counters if F._same_trigger_object(g, s) else s.last_counters
	var n := int(counters.get("pain", 0))
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	if n > 0: g.deal_damage(s, TargetRef.player(pid), n)


# ---------------------------------------------------------------- Excavator --

class Excavate extends GrantLandwalkEffect:
	func _init() -> void:
		super([])
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var types: Array = g.cost_paid("_sacrificed_subtypes", [])
		if types.is_empty(): return
		g.continuous.add_until_eot_landwalk(i.id, types)
		g.recalculate()
	func describe() -> String:
		return "target creature gains landwalk of each of the sacrificed land's land types until end of turn"


# ------------------------------------------------------ Flowstone Sculpture --

const SCULPT_OPTIONS: Array[String] = ["Put a +1/+1 counter on it", "Flying", "First strike", "Trample"]
const SCULPT_KEYWORDS := [-1, Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]

## The Sculpture's own sensible answer: an evasion it lacks first, then
## trample, then first strike, else the counter.
static func sculpt_hint(s: CardInstance) -> int:
	for index in [1, 3, 2]:
		if not s.has_keyword(SCULPT_KEYWORDS[index]): return index
	return 0

class Sculpt extends CounterMarkerEffect:
	func _init() -> void:
		super("+1/+1")
		target_spec = null
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		if not F._same_activation_source(g, s): return
		var module: GDScript = load(PATH)
		var picked: int = g.agents[pid].choose_option(g, pid, module.SCULPT_OPTIONS,
			"Flowstone Sculpture: a +1/+1 counter, or a keyword", module.sculpt_hint(s))
		if picked <= 0:
			g.add_counters(s, kind, count)
		else:
			g.grant_keyword_permanently(s, int(module.SCULPT_KEYWORDS[picked]))
	func describe() -> String:
		return "put a +1/+1 counter on this creature or it gains flying, first strike, or trample"


# --------------------------------------------------------------- Fool's Tome --

static func _empty_hand(g: MtgGame, s: CardInstance) -> String:
	return "" if g.players[s.controller_id].hand.is_empty() else "activate only if you have no cards in hand"


# ---------------------------------------------------------------- Grindstone --

class Grind extends MillEffect:
	func _init() -> void:
		super(2)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id if t != null and t.is_player else pid
		# Each pass takes two cards off the library, so the loop ends.
		while true:
			var library: Array[CardInstance] = g.players[who].library
			if library.size() < 2:
				g.mill(who, library.size())   # fewer than two milled: no repeat
				return
			var first: CardInstance = library[-1]
			var second: CardInstance = library[-2]
			g.mill(who, 2)
			if first.zone != Mtg.Zone.GRAVEYARD or second.zone != Mtg.Zone.GRAVEYARD: return
			if (first.data.color_mask() & second.data.color_mask()) == 0: return
	func describe() -> String:
		return "target player mills two cards; repeat while the two share a color"


# -------------------------------------------------------- Helm of Possession --

class Possess extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var prize := g.find_instance(t.instance_id)
		if not g.is_present(prize): return
		# Not the same Helm, not its activator's any more, or untapped since:
		# the duration has already ended, so the effect does nothing.
		if not F._original_source(g, s, pid) or not F._remained_tapped(g, s): return
		g.gain_control_leashed(prize, s, true)
	func describe() -> String:
		return "gain control of target creature while you control this artifact and it remains tapped"


# --------------------------------------------------------------- Jinxed Idol --

static func _idol_bite(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	g.deal_damage(s, TargetRef.player(pid), 2)

class Jinx extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s) and t != null and t.is_player:
			g.change_control(s, t.player_id)
	func describe() -> String:
		return "target opponent gains control of this artifact"


# --------------------------------------------------------------- Mogg Cannon --

class Cannon extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(F._own).because("controller")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var flying: Array[int] = [Mtg.Keyword.FLYING]
		g.continuous.add_until_eot_pump(i.id, 1, 0, flying)
		g.recalculate()
		g.doom_at_next_end_step(i)
	func describe() -> String:
		return "target creature you control gets +1/+0 and flying; destroy it at the next end step"


# ------------------------------------------------------------ Puppet Strings --

const STRINGS_OPTIONS: Array[String] = ["Tap it", "Untap it", "Leave it as it is"]

class Strings extends TapEffect:
	func _init() -> void:
		super(TargetSpec.creature())
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var hint := 2
		if i.controller_id == pid and i.tapped: hint = 1
		elif i.controller_id != pid and not i.tapped: hint = 0
		var module: GDScript = load(PATH)
		var picked: int = g.agents[pid].choose_option(g, pid, module.STRINGS_OPTIONS,
			"Puppet Strings: tap or untap %s?" % i.data.card_name, hint)
		if picked == 0: g.tap_permanent(i)
		elif picked == 1: g.untap_permanent(i)
	func describe() -> String:
		return "you may tap or untap target creature"


# ------------------------------------------------ Scalding Tongs / Thumbscrews --

static func _hand_holds(g: MtgGame, pid: int, limit: int, fewer: bool) -> bool:
	var n := g.players[pid].hand.size()
	return n <= limit if fewer else n >= limit

static func _tongs_due(g: MtgGame, s: CardInstance, e: GameEvent, limit: int, fewer: bool) -> bool:
	return F._your_upkeep(g, s, e) and _hand_holds(g, s.controller_id, limit, fewer)

## CR 603.4: the "if" is asked again as the trigger resolves.
static func _tongs(g: MtgGame, s: CardInstance, _e: GameEvent, limit: int, fewer: bool) -> void:
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	if not _hand_holds(g, pid, limit, fewer): return
	var refs: Array = g.current_targets()
	if refs.is_empty(): return
	g.deal_damage(s, refs[0], 1)
