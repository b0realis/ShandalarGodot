extends RefCounted
## Stronghold (_artifacts, Pack 9). Noncreature artifacts and their activated or static abilities.
##
## - Ensnaring Bridge is an ordinary static (reading live power), so the
##   1997 "tapped artifacts stop" rule (fifth preset,
##   cur_statics_suspended) switches it off with no card code. "Your hand"
##   is its controller's, counted at each recalculation; the engine
##   recalculates on a draw, a discard or a cast and again as attackers and
##   blockers are declared (MtgGame._refresh_after_hand_change, Pack 9), so
##   the restriction is judged on the live hand.
## - Jinxed Ring hears every departure to a graveyard: a NONTOKEN
##   permanent whose OWNER is the Ring's controller (that is whose
##   graveyard it goes to) — the Ring itself included (a leaves-the-
##   battlefield trigger looks back, CR 603.10a). Its control change has
##   no end (CR 611.2b: "lasts indefinitely").
## - Portcullis: the intervening "if" (CR 603.4) is asked as the creature
##   enters and again as the trigger resolves — two or more creatures OTHER
##   than that one. The exiled card is linked to THIS Portcullis only while
##   it is the object that triggered (CR 607.2a): a Portcullis gone by then
##   has had its leaves trigger already, and the card stays exiled. The
##   leaves trigger reads the link from the departing object's memory.
## - Hornet Cannon's Hornet is destroyed by the end-step doom (not
##   sacrificed): regeneration may replace it.
## - Volrath's Laboratory chooses its colour and creature type as it enters
##   (CR 614.1c); the activation snapshots them with its cost, so the token
##   still has them if the Laboratory is gone when the ability resolves
##   (CR 608.2h).
## - Sword of the Chosen is legendary: the engine's (1997) legend rule
##   buries the newer of two copies.
## tests/cards/test_pack_9_B10_artifacts.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const TYPES := preload("res://engine/core/creature_types.gd")
const COLOR_NAMES := {Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue", Mtg.ManaColor.B: "black",
	Mtg.ManaColor.R: "red", Mtg.ManaColor.G: "green"}

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bullwhip":
			c.activated(ActivatedAbility.new("{2}", true, [Whip.new()],
				"{2}, {T}: This artifact deals 1 damage to target creature. That creature attacks this turn if able."))
		"Ensnaring Bridge":
			var bridge := StaticAbility.new(_bridge,
				"Creatures with power greater than the number of cards in your hand can't attack.").reading_pt()
			# The fair AI's shape (the Pack 9 bug pass, h6-5;
			# engine/ai/tempest_spells.gd `bridge_choice`): both sides' attackers
			# above the caster's hand size stay home.
			bridge.set_meta(&"ai_role", &"hand_size_attack_cap")
			c.static_ability(bridge)
		"Horn of Greed":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LAND_PLAYED, _horn,
				"Whenever a player plays a land, that player draws a card."))
		"Hornet Cannon":
			c.activated(ActivatedAbility.new("{3}", true, [HornetToken.new()],
				"{3}, {T}: Create a 1/1 colorless Insect artifact creature token with flying and haste named Hornet. Destroy it at the beginning of the next end step."))
		"Jinxed Ring":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _ring_burn,
				"Whenever a nontoken permanent is put into your graveyard from the battlefield, this artifact deals 1 damage to you.",
				_ring_heard).capturing(_ring_context))
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_ring_give, "target opponent gains control of this artifact", TargetSpec.opponent()) \
					.with_ai_role(&"donate_self")],
				"Sacrifice a creature: Target opponent gains control of this artifact. (This effect lasts indefinitely.)") \
				.with_sacrifice_of("creature", _creature))
		"Portcullis":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _portcullis_exile,
				"Whenever a creature enters, if there are two or more other creatures on the battlefield, exile that creature.",
				_portcullis_heard).capturing(_portcullis_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _portcullis_release,
				"Return that card to the battlefield under its owner's control when this artifact leaves the battlefield.",
				F._self_enter))
		"Shifting Wall":
			c.as_it_enters(_x_counters)
		"Sword of the Chosen":
			var pump := PumpEffect.new(2, 2)
			pump.target_spec = TargetSpec.creature("target legendary creature", _legendary).because("type")
			c.activated(ActivatedAbility.new("", true, [pump], "{T}: Target legendary creature gets +2/+2 until end of turn."))
		"Volrath's Laboratory":
			c.as_it_enters(_lab_choose).with_chosen_type("lab_type")
			var lab := ActivatedAbility.new("{5}", true, [LabToken.new()],
				"{5}, {T}: Create a 2/2 creature token of the chosen color and type.")
			lab.on_cost_paid = _lab_paid
			c.activated(lab)
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _legendary(i: CardInstance) -> bool: return (i.cur_supertypes & Mtg.Supertype.LEGENDARY) != 0
static func _you(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))


# ------------------------------------------------------------------ Bullwhip --

## The damage, then the requirement on the creature that was targeted —
## whatever the damage did, while it is still there (a prevented ping still
## makes it attack). A DamageEffect for the AI's readers.
class Whip extends DamageEffect:
	func _init() -> void:
		super(1)
		target_creature()
		with_ai_role(&"ping_and_force_attack")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		var stamp := i.layer_timestamp
		g.deal_damage(s, t, amount)
		if g.is_present(i) and i.layer_timestamp == stamp:
			g._rec(i, &"must_attack_this_turn")
			i.must_attack_this_turn = true
			g.log_line("%s attacks this turn if able" % i.data.card_name)
	func describe() -> String:
		return "deals 1 damage to target creature; that creature attacks this turn if able"


# ---------------------------------------------------------- Ensnaring Bridge --

## The Bridge's controller drew, discarded or cast a card.
static func _bridge(g: MtgGame, s: CardInstance) -> void:
	var n := g.players[s.controller_id].hand.size()
	for i in g.all_battlefield():
		if i.is_creature() and i.cur_power > n: i.cur_cant_attack = true


# ------------------------------------------------------------- Horn of Greed --

static func _horn(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0: g.draw_cards(who, 1)


# ------------------------------------------------------------- Hornet Cannon --

## The Hornet: a 1/1 colorless Insect ARTIFACT creature with flying and
## haste (CR 111.4 — exactly what the effect names).
class HornetToken extends CreateTokenEffect:
	func _init() -> void:
		super("Hornet", 1, 1, 0, "insect")
		token.types |= Mtg.CardType.ARTIFACT
		token.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.HASTE]).oracle("Flying, haste")
		with_ai_role(&"hasty_token")   # a main-1 attacker (Balduvian Dead's reading)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for i in g.create_token(pid, token, 1):
			g.doom_at_next_end_step(i)
	func describe() -> String:
		return "create a 1/1 colorless Insect artifact creature token with flying and haste named Hornet; destroy it at the beginning of the next end step"


# --------------------------------------------------------------- Jinxed Ring --

## "Your": the Ring's controller — as it last was on the battlefield when
## the departing permanent is the Ring itself (CR 603.10a; leaving resets
## a card's controller to its owner, so the event's `from_controller`).
static func _ring_controller(s: CardInstance, e: GameEvent) -> int:
	if e.data.get("instance") == s:
		return int(e.data.get("from_controller", s.controller_id))
	return s.controller_id

static func _ring_heard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and not i.is_token and i.zone == Mtg.Zone.GRAVEYARD \
		and i.owner_id == _ring_controller(s, e)

static func _ring_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": _ring_controller(s, e)}

static func _ring_burn(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.deal_damage(s, TargetRef.player(_you(g, s)), 1)

static func _ring_give(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	if F._same_activation_source(g, s): g.change_control(s, t.player_id)


# ---------------------------------------------------------------- Portcullis --

static func _others(g: MtgGame, entrant_id: int) -> int:
	var n := 0
	for i in g.all_battlefield():
		if i.is_creature() and i.id != entrant_id: n += 1
	return n

static func _portcullis_heard(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i != s and i.is_creature() and _others(g, i.id) >= 2

static func _portcullis_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, s, e)
	var i: CardInstance = e.data.get("instance")
	out["entrant"] = i.id if i != null else -1
	out["entrant_stamp"] = i.layer_timestamp if i != null else -1
	return out

static func _portcullis_exile(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get("entrant", -1)))
	if not g.is_present(i) or i.layer_timestamp != int(ctx.get("entrant_stamp", -2)): return
	if _others(g, i.id) < 2:
		g.log_line("Portcullis: fewer than two other creatures — %s stays" % i.data.card_name)
		return
	var linked := F._same_trigger_source(g, s)
	g.exile_permanent(i)
	if not linked or i.is_token or i.zone != Mtg.Zone.EXILE: return
	var held: Array = (s.memory.get("portcullis", []) as Array).duplicate()
	held.append([i.id, i.exile_entry])
	g._rec(s, &"memory")
	s.memory["portcullis"] = held

## The departing Portcullis's memory snapshot travels with the event.
static func _portcullis_release(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var memory: Dictionary = e.data.get("memory", {})
	var back: Array[CardInstance] = []
	for row in memory.get("portcullis", []):
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(row[1]): back.append(i)
	if back.is_empty(): return
	g.begin_simultaneous()
	for i in back: g.return_from_exile_to_play(i, i.owner_id)
	g.end_simultaneous()


# ------------------------------------------------------------- Shifting Wall --

## "Enters with X +1/+1 counters" — a replacement (CR 614.1c), so it is
## never a 0/0 on the battlefield; X is 0 when it was not cast.
static func _x_counters(g: MtgGame, inst: CardInstance, _pid: int) -> void:
	var x := int(inst.memory.get("x_value", 0))
	if x > 0: g.add_counters(inst, "+1/+1", x)


# ------------------------------------------------------ Volrath's Laboratory --

## Hints, public board only: the colour and the creature type the chooser's
## own permanents show most.
static func _lab_choose(g: MtgGame, s: CardInstance, pid: int) -> void:
	var colors := {}
	var kinds := {}
	for i in g.players[pid].battlefield:
		for c in Mtg.WUBRG:
			if (i.cur_colors & c) != 0: colors[c] = int(colors.get(c, 0)) + 1
		if i.is_creature():
			for sub in i.cur_subtypes: kinds[sub] = int(kinds.get(sub, 0)) + 1
	var color_hint: int = Mtg.ManaColor.B
	var most := 0
	for c in Mtg.WUBRG:
		if int(colors.get(c, 0)) > most:
			most = int(colors.get(c, 0))
			color_hint = c
	var color := g.agents[pid].choose_color(g, pid, "Volrath's Laboratory: choose a color", color_hint)
	var type_hint := 0
	var score := 0
	for index in TYPES.ALL.size():
		var n := int(kinds.get(TYPES.ALL[index].to_lower(), 0))
		if n > score:
			score = n
			type_hint = index
	var pick := g.agents[pid].choose_option(g, pid, TYPES.ALL,
		"Volrath's Laboratory: choose a creature type", type_hint)
	var kind: String = TYPES.ALL[clampi(pick, 0, TYPES.ALL.size() - 1)]
	g._rec(s, &"memory")
	s.memory["lab_color"] = color
	s.memory["lab_type"] = kind.to_lower()
	g.log_line("Volrath's Laboratory: %s chooses %s and %s" % [g.players[pid].player_name,
		COLOR_NAMES.get(color, "colorless"), kind])

static func _lab_paid(_g: MtgGame, source: CardInstance, paid: Dictionary) -> void:
	paid["_lab_color"] = int(source.memory.get("lab_color", -1))
	paid["_lab_type"] = String(source.memory.get("lab_type", ""))

## The token is built as the ability resolves from the choice its cost
## recorded; the 2/2 body on the effect is what the AI's planner prices
## (EffectIntent reads a CreateTokenEffect's token).
class LabToken extends CreateTokenEffect:
	func _init() -> void:
		super("Creature", 2, 2, 0, "creature")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var color := int(g.cost_paid("_lab_color", -1))
		var kind := String(g.cost_paid("_lab_type", ""))
		if color < 0 or kind == "":
			g.log_line("Volrath's Laboratory: no color and type were chosen — no token")
			return
		var made := CardData.new(kind.capitalize(), "", Mtg.CardType.CREATURE).pt(2, 2) \
			.with_colors(color).with_subtypes([kind])
		g.create_token(pid, made, 1)
	func describe() -> String:
		return "create a 2/2 creature token of the chosen color and type"
