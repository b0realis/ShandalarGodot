extends RefCounted
## Reusable Alliances effects: the same typed effects serve the rules,
## human target picker, forecasts and fair AI evaluation.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const H := preload("res://cards/sets/hml/_spells.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Elvish Ranger", "Kjeldoran Escort", "Storm Crow": pass
		"Aesthir Glider": c.static_ability(StaticAbility.new(_no_block, "This creature can't block."))
		"Deadly Insect": c.static_ability(StaticAbility.new(_shroud, "Shroud."))
		"Elvish Bard": c.static_ability(StaticAbility.new(_lure, "All creatures able to block this creature do so."))
		"Balduvian War-Makers": c.rampage = 1
		"Gorilla Berserkers":
			c.rampage = 2
			c.static_ability(StaticAbility.new(_three_blockers, "Can't be blocked except by three or more creatures."))
		"Storm Shaman": c.activated(F._ability("{R}", false, PumpEffect.new(1, 0).self_buff()))
		"Yavimaya Ancients": c.activated(F._ability("{G}", false, PumpEffect.new(1, -2).self_buff()))
		"Wild Aesthir": c.activated(F._ability("{W}{W}", false, PumpEffect.new(2, 0).self_buff()).per_turn(1))
		"Gorilla Chieftain": c.activated(F._ability("{1}{G}", false, RegenerateEffect.new()))
		"Lim-Dûl's High Guard": c.activated(F._ability("{1}{B}", false, RegenerateEffect.new()))
		"Yavimaya Ants": CumulativeUpkeep.attach(c, "{G}{G}")
		"Phantasmal Fiend":
			c.activated(F._ability("{B}", false, PumpEffect.new(1, -1).self_buff()))
			c.activated(F._ability("{1}{U}", false, F.Action.new(_switch, "switch this creature's power and toughness until end of turn", null, true)))
		"Noble Steeds": c.activated(F._ability("{1}{W}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE])))
		"Unlikely Alliance":
			var effect := PumpEffect.new(0, 2)
			effect.target_spec.with_game_filter(_not_fighting)
			c.activated(F._ability("{1}{W}", false, effect))
		"Enslaved Scout": c.activated(F._ability("{2}", false, F.Action.new(_mountainwalk, "gain mountainwalk until end of turn", null, true)))
		"Agent of Stromgald": c.mana(ManaAbility.new(Mtg.ManaColor.B).without_tap().with_mana_cost("{R}").with_plannable_conversion())
		"School of the Unseen":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			for color in Mtg.WUBRG: c.mana(ManaAbility.new(color).with_mana_cost("{2}").with_plannable_conversion())
		"Soldevi Adnate": c.mana(ManaAbility.new(Mtg.ManaColor.B).with_sacrifice_of("black or artifact creature", _adnate_food).may_sacrifice_itself().scaling_with_sacrifice())
		"Carrier Pigeons": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _slow_draw, "Draw next turn's upkeep.", F._self_enter))
		"Kaysa", "Juniper Order Advocate": c.static_ability(StaticAbility.new(_green_anthem, "Your green creatures get +1/+1 while this ability applies."))
		"Shield Sphere": c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _shield, "Put a -0/-1 counter on this creature.", _blocks))
		"Whirling Catapult": c.activated(F._ability("{2}", false, DamageAllEffect.new(1, "each creature with flying", _flying).and_each_player()).with_library_exile_cost(2))
		"Royal Herbalist": c.activated(F._ability("{2}", false, GainLifeEffect.new(1)).with_library_exile_cost(1))
		"Krovikan Horror":
			c.activated(F._ability("{1}", false, DamageEffect.new(1).any_target()).with_sacrifice_of("creature", _creature).may_sacrifice_itself())
			c.with_graveyard_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _grave_return, "May return this card to hand if a creature is directly above it.", _creature_above).capturing(_grave_context))
		"Death Spark":
			c.spell(DamageEffect.new(1).any_target())
			c.with_graveyard_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _grave_return, "May pay {1} to return this card to hand if a creature is directly above it.", _spark_upkeep).capturing(_grave_context))
		"Viscerid Armor":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.activated(F._ability("{1}{U}", false, F.Action.new(_return_self, "return this Aura to its owner's hand", null, true)))
		"Kjeldoran Pride":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(F._aura_pump.bind(1, 2), "Enchanted creature gets +1/+2."))
			c.activated(F._ability("{2}{U}", false, F.Action.new(_reattach, "attach this Aura to another target creature", TargetSpec.creature().with_source_filter(_not_host), true)))
		"Phyrexian Boon":
			c.enchants(TargetSpec.creature()).static_ability(StaticAbility.new(_boon, "Black enchanted creature gets +2/+1; otherwise -1/-2."))
		"Fevered Strength": c.spell(PumpEffect.new(2, 0)).spell(DelayedDrawEffect.new())
		"Reprisal": c.spell(DestroyEffect.new(TargetSpec.creature("target creature with power 4 or greater", _large), false))
		"Pillage": c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or land", _artifact_land), false))
		"Ritual of the Machine":
			c.with_additional_sacrifice("creature", _creature)
			c.spell(F.Action.new(_steal, "gain control of target nonartifact, nonblack creature", TargetSpec.creature("target nonartifact, nonblack creature", _nonartifact_nonblack)))
		"Errand of Duty":
			var token := CreateTokenEffect.new("Knight", 1, 1, Mtg.ManaColor.W, "knight")
			token.token.with_keywords([Mtg.Keyword.BANDING])
			c.spell(token)
		"Feast or Famine":
			c.mode("Create a 2/2 black Zombie", [CreateTokenEffect.new("Zombie", 2, 2, Mtg.ManaColor.B, "zombie")])
			c.mode("Destroy nonartifact, nonblack creature", [DestroyEffect.new(TargetSpec.creature("target nonartifact, nonblack creature", _nonartifact_nonblack), false)])
		"Stench of Decay": c.spell(F.Action.new(_decay, "nonartifact creatures get -1/-1 until end of turn"))
		"Mystic Compass": c.activated(F._ability("{1}", true, F.Action.new(H._jinx, "target land becomes a basic land type of your choice until end of turn", TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))))
		"Soldier of Fortune": c.activated(F._ability("{R}", true, F.Action.new(_shuffle, "target player shuffles their library", TargetSpec.player())))
		_: return false
	return true

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _large(i: CardInstance) -> bool: return i.cur_power >= 4
static func _artifact_land(i: CardInstance) -> bool: return i.is_land() or i.is_type(Mtg.CardType.ARTIFACT)
static func _nonartifact_nonblack(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT) and (i.cur_colors & Mtg.ManaColor.B) == 0
static func _adnate_food(i: CardInstance) -> bool: return i.is_creature() and (i.is_type(Mtg.CardType.ARTIFACT) or (i.cur_colors & Mtg.ManaColor.B) != 0)
static func _no_block(_g: MtgGame, s: CardInstance) -> void: s.cur_cant_block_filter = _anything
static func _anything(_i: CardInstance) -> bool: return true
static func _shroud(_g: MtgGame, s: CardInstance) -> void: s.cur_shroud = true
static func _lure(_g: MtgGame, s: CardInstance) -> void: s.cur_must_be_blocked = true
static func _three_blockers(_g: MtgGame, s: CardInstance) -> void: s.cur_min_blockers = maxi(3, s.cur_min_blockers)
static func _not_fighting(g: MtgGame, i: CardInstance) -> bool: return not g.combat.attackers.has(i.id) and not F._blocking(g, i)
static func _blocks(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return F._blocking(g, s)
static func _not_host(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return s.attached_to != i.id
static func _green_anthem(g: MtgGame, s: CardInstance) -> void:
	if s.data.card_name == "Juniper Order Advocate" and s.tapped: return
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.G) != 0:
			i.cur_power += 1
			i.cur_toughness += 1
static func _switch(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not live_source(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_until_eot_pt_switch(s.id)
	g.recalculate()
static func live_source(g: MtgGame, s: CardInstance) -> bool:
	return s.zone == Mtg.Zone.BATTLEFIELD and s.layer_timestamp == int(g.cost_paid("_source_timestamp", s.layer_timestamp))
static func _mountainwalk(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not live_source(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_floating_static(s, StaticAbility.new(_walk, "Mountainwalk.").changing_abilities(), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()
static func _walk(_g: MtgGame, s: CardInstance) -> void: s.cur_landwalk.append("mountain")
static func _slow_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: DelayedDrawEffect.new().resolve(g, s, int(g.trigger_context(s).controller), null)
static func _shield(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.add_counters(s, "-0/-1")
static func _creature_above(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	var grave := g.players[s.owner_id].graveyard
	var index := grave.find(s)
	return index >= 0 and index + 1 < grave.size() and grave[index + 1].is_creature()
static func _spark_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.owner_id and _creature_above(g, s, e)
static func _grave_context(_g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary: return {"entry": s.graveyard_entry}
static func _grave_return(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(g.trigger_context(s).entry) or not _creature_above(g, s, e): return
	if s.data.card_name == "Death Spark":
		if not EffectBase.unless_paid(g, s.owner_id, ManaCost.parse("{1}"), "Pay {1} to return Death Spark?", true): return
	elif not g.agents[s.owner_id].choose_yes_no(g, s.owner_id, "Return Krovikan Horror to your hand?", true): return
	g.return_from_graveyard_to_hand(s)
static func _return_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if live_source(g, s): g.return_to_hand(s)
static func _reattach(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if live_source(g, s): g.move_aura(s, g.find_instance(t.instance_id))
static func _boon(g: MtgGame, s: CardInstance) -> void:
	var host := A.host(g, s)
	if host == null: return
	var black := (host.cur_colors & Mtg.ManaColor.B) != 0
	host.cur_power += 2 if black else -1
	host.cur_toughness += 1 if black else -2
static func _steal(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	g.change_control(g.find_instance(t.instance_id), pid)
static func _decay(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and not i.is_type(Mtg.CardType.ARTIFACT): g.continuous.add_until_eot_pump(i.id, -1, -1)
	g.recalculate()
static func _shuffle(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void: g.shuffle_library(t.player_id)

## "Draw N cards, then discard one of them" (Soldevi Sage, Casting of Bones):
## the discard is bounded to the cards this draw put in hand, not the whole
## hand. [param before] is drawn_this_turn's size taken before the draw —
## Krovikan Sorcerer's shape (cards/sets/ice/_storage.gd).
static func discard_one_just_drawn(g: MtgGame, pid: int, before: int, prompt: String) -> void:
	var candidates: Array[CardInstance] = []
	for n in range(before, g.players[pid].drawn_this_turn.size()):
		var i: CardInstance = g.players[pid].drawn_this_turn[n]
		if i.zone == Mtg.Zone.HAND and not candidates.has(i): candidates.append(i)
	if candidates.is_empty(): return
	# Declining is not legal here, so a null answer becomes the first
	# candidate (DecisionAgent.choose_card's contract for optional = false).
	var pick := g.agents[pid].choose_card(g, pid, candidates, prompt, false, true)
	if pick == null or not candidates.has(pick): pick = candidates[0]
	g.discard_cards(pid, [pick])
