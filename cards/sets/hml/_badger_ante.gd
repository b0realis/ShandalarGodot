extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Rysorian Badger":
			var spec := TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD, "target creature card in defending player's graveyard").with_source_filter(_defending_graveyard)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _badger, "You may exile up to two targets, gain life and assign no combat damage this turn.", F._self_enter).targeting_up_to(spec, 2, _largest_first))
		"Timmerian Fiends":
			# SIMPLIFIED: token ownership exchange is intentionally unavailable;
			# the digital collection contains physical card identities only.
			# Ordinary cards keep the full owner-choice / from-anywhere flow.
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nontoken artifact", _artifact_card)
			c.activated(F._ability("{B}{B}{B}", false, F.Action.new(_fiends, "artifact's owner may ante their top card; otherwise exchange ownership and put both cards into their new owners' graveyards", spec)).with_sacrifice_cost().only_if(_physical_source))
			c.oracle_text += "\nDigital adaptation: only nontoken cards can take part in this ownership exchange."
		_: return false
	return true

static func _defending_graveyard(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return i.owner_id == 1 - int(g.trigger_context(s).get("controller", s.controller_id))
static func _largest_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	return ia.cur_power + ia.cur_toughness > ib.cur_power + ib.cur_toughness
static func _badger(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var refs := g.current_targets()
	if refs.is_empty(): return
	var pid := int(g.trigger_context(s).controller)
	if not g.agents[pid].choose_yes_no(g, pid, "Exile the targeted creature cards and gain life instead of assigning combat damage?", g.players[pid].life <= 8): return
	var exiled := 0
	for ref in refs:
		var i := g.find_instance(ref.instance_id)
		g.exile_from_graveyard(i)
		if i.zone == Mtg.Zone.EXILE: exiled += 1
	g.adjust_life(pid, exiled)
	if F._same_trigger_source(g, s) and g.is_present(s): F._no_assignment(g, s, s.id)   # CR 702.26e
static func _artifact_card(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT) and not i.is_token
static func _physical_source(_g: MtgGame, s: CardInstance) -> String:
	return "Digital adaptation: token copies cannot exchange ownership" if s.is_token else ""
static func _fiends(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var artifact := g.find_instance(t.instance_id)
	var their_owner := artifact.owner_id
	if not g.players[their_owner].library.is_empty() and g.agents[their_owner].choose_yes_no(g, their_owner, "Ante the top card of your library to keep %s?" % artifact.data.card_name, true):
		g.ante_top_of_library(their_owner)
		return
	var our_owner := s.owner_id
	g.begin_simultaneous()
	g.change_owner(artifact, our_owner)
	g.change_owner(s, their_owner)
	# CR 400.3 redirects any wrong-owner graveyard instruction to the
	# actual owner's graveyard, including a stolen Fiends' exchange.
	g.card_to_graveyard_from_anywhere(artifact)
	g.card_to_graveyard_from_anywhere(s)
	g.end_simultaneous()
