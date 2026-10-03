extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const O := preload("res://cards/sets/hml/_oyster_redirect.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Gustha's Scepter":
			c.activated(F._ability("", true, F.Action.new(_hide, "exile a card from your hand face down; only you may look at it", null, true)))
			c.activated(F._ability("", true, F.Action.new(_recover, "return an owned card exiled with this artifact to hand", null, true)))
			c.triggered(TriggeredAbility.new(Mtg.EventType.CONTROL_CHANGED, _lost, "Put cards exiled with this artifact into their owners' graveyards.", F._self_enter).also_when(Mtg.EventType.LEAVES_BATTLEFIELD).capturing(_links_context))
		"Martyrdom": c.spell(F.Action.new(_martyrdom, "grant target creature you control a free one-point redirection ability until end of turn; only you may activate it", TargetSpec.creature().with_source_filter(F._own), true).as_damage_prevention())
		_: return false
	return true

static func _hide(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards: Array[CardInstance] = g.players[pid].hand.duplicate()
	if cards.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, cards, "Exile a card face down with Gustha's Scepter")
	if pick == null or not cards.has(pick): pick = cards[0]
	g.exile_from_hand(pick, true, pid)
	if B.live_source(g, s):
		g._rec(s, &"memory")
		var linked: Array = s.memory.get("all_scepter", []).duplicate()
		linked.append([pick.id, pick.exile_entry])
		s.memory["all_scepter"] = linked
static func _linked(g: MtgGame, rows: Array) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for row in rows:
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(row[1]): cards.append(i)
	return cards
static func _recover(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s): return
	var cards: Array[CardInstance] = []
	for i in _linked(g, s.memory.get("all_scepter", [])):
		if i.owner_id == pid: cards.append(i)
	if cards.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, cards, "Return an owned card exiled with Gustha's Scepter")
	if pick != null and cards.has(pick): g.return_from_exile_to_hand(pick, false)
static func _links_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary: return {"links": e.data.get("memory", s.memory).get("all_scepter", []).duplicate(true)}
static func _lost(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for i in _linked(g, g.trigger_context(s).links): g.return_from_exile_to_graveyard(i)
static func _martyrdom(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var ability := F._ability("", false, AnyRedirect.new()).anyone_activated()
	ability.activator_condition = _only_you.bind(pid)
	g.continuous.add_granted_activated_ability(t.instance_id, ability, ContinuousEffects.Duration.END_OF_TURN)
	g.recalculate()
static func _only_you(_g: MtgGame, _s: CardInstance, who: int, original: int) -> String: return "" if who == original else "Only the player who cast Martyrdom may activate this ability"
class AnyRedirect extends CreatureRedirectEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.any_target()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if not B.live_source(g, s) or not g.is_present(s): return   # CR 702.26e
		if not t.is_player:
			super(g, s, pid, t, x)
			return
		var p := g.players[t.player_id]
		g._rec(p, &"damage_replacements")
		p.damage_replacements.append({"desc": "Martyrdom: redirect the next 1 damage", "filter": _exists.bind(s.id, s.layer_timestamp), "apply": _redirect.bind(s.id, s.layer_timestamp)})
	static func _exists(g: MtgGame, packet: DamagePacket, id: int, stamp: int) -> bool: return packet.remaining() > 0 and O._live(g, id, stamp) != null
	static func _redirect(g: MtgGame, packet: DamagePacket, id: int, stamp: int) -> int:
		var recipient := O._live(g, id, stamp)
		if recipient == null: return -1
		var amount := packet.divert(1)
		var split := g._plan_damage(packet.source, TargetRef.card(recipient), amount, packet.is_combat, true, packet.unpreventable_to_creatures)
		if split != null:
			split.source_was_spell = packet.source_was_spell
			split.source_timestamp = packet.source_timestamp
			split.local_prevention = packet.local_prevention
			split.applied_creature_redirects = packet.applied_creature_redirects.duplicate()
			if g._damage_window_armed(): split.after_landing = packet.after_landing.duplicate()
			if not g._damage_window_armed() or not g._queue_damage(split): g._land_damage(split)
		return -1
	func describe() -> String: return "the next 1 damage to any target this turn is dealt to this creature instead"
