extends RefCounted
## Weatherlight (_spells, Pack 8). Instants and sorceries: one-shot spell effects, modes, X spells and their targets.
##
## Every listed name implements its whole Oracle text, with the shared
## typed effects wherever they can say it so the fair AI reads the spell.
## Abeyance rides the E4 floating bans, Urborg Justice the E10 owner-keyed
## death tracker, Gaea's Blessing the E7 library-to-graveyard event.
const F := preload("res://cards/sets/fem/_rules.gd")
const V := preload("res://cards/sets/vis/_creatures.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Argivian Find":
			c.spell(_from_graveyard("target artifact or enchantment card in your graveyard", _artifact_or_enchantment))
		"Argivian Restoration":
			c.spell(_from_graveyard("target artifact card in your graveyard", _artifact).to_battlefield())
		"Relearn":
			c.spell(_from_graveyard("target instant or sorcery card in your graveyard", _instant_or_sorcery))
		"Debt of Loyalty":
			c.spell(V.ThisWayRegeneration.new("debt", TargetSpec.creature()))
		"Gerrard's Wisdom":
			c.spell(LifePerCount.new("hand", 2, "you gain 2 life for each card in your hand"))
		"Blossoming Wreath":
			c.spell(LifePerCount.new("creature cards in graveyard", 1, "you gain life equal to the number of creature cards in your graveyard"))
		"Guided Strike":
			c.spell(PumpEffect.new(1, 0, [Mtg.Keyword.FIRST_STRIKE])).spell(DrawEffect.new(1))
		"Fit of Rage":
			c.spell(PumpEffect.new(3, 3, [Mtg.Keyword.FIRST_STRIKE]))
		"Disrupt":
			var toll := F.TollCounter.new("{1}", "", _instant_or_sorcery)
			toll.target_spec.description = "target instant or sorcery spell"
			c.spell(toll).spell(DrawEffect.new(1))
		"Paradigm Shift":
			c.spell(F.Action.new(_paradigm, "exile all cards from your library, then shuffle your graveyard into your library"))
		"Agonizing Memories":
			c.spell(F.Action.new(_memories, "look at target player's hand and put two cards from it on top of their library in any order", TargetSpec.player()))
		"Buried Alive":
			c.spell(F.Action.new(_bury, "search your library for up to three creature cards and put them into your graveyard", null, true))
		"Fatal Blow":
			c.spell(DestroyEffect.new(TargetSpec.creature("target creature that was dealt damage this turn", _damaged_this_turn).because(TargetSpec.WHY["damaged"]), false))
		"Shattered Crypt":
			c.spell(ReturnFromGraveyardEffect.new().x_targets()).spell(LoseXLife.new())
		"Boiling Blood":
			c.spell(F.Action.new(_must_attack, "target creature attacks this turn if able", TargetSpec.creature())).spell(DrawEffect.new(1))
		"Cone of Flame":
			# "another target" and "a third target": three DIFFERENT targets
			# (CR 115.3 lets one object be several targets unless the text
			# says otherwise — this text does).
			c.spell(DamageEffect.new(1).any_target())
			var second := DamageEffect.new(2).any_target()
			second.target_spec.description = "another target"
			second.target_spec.with_sibling_filter(_distinct, TargetSpec.WHY["cant_target"])
			var third := DamageEffect.new(3).any_target()
			third.target_spec.description = "a third target"
			third.target_spec.with_sibling_filter(_distinct, TargetSpec.WHY["cant_target"])
			c.spell(second).spell(third)
		"Thunderbolt":
			c.mode("Thunderbolt deals 3 damage to target player", [DamageEffect.new(3).target_player()])
			c.mode("Thunderbolt deals 4 damage to target creature with flying", [DamageEffect.new(4).target_creature("target creature with flying", _flying)])
			c.with_ai_mode(_thunderbolt_mode)
		"Nature's Resurgence":
			c.spell(F.Action.new(_resurgence, "each player draws a card for each creature card in their graveyard"))
		"Vitalize":
			c.spell(F.Action.new(_vitalize, "untap all creatures you control", null, true))
		"Abeyance":
			c.spell(F.Action.new(_abeyance, "until end of turn, target player can't cast instant or sorcery spells or activate abilities that aren't mana abilities", TargetSpec.player()))
			c.spell(DrawEffect.new(1))
		"Urborg Justice":
			c.spell(F.Action.new(_justice, "target opponent sacrifices a creature for each creature put into your graveyard from the battlefield this turn", TargetSpec.opponent()))
		"Gaea's Blessing":
			# "Target player shuffles up to three target cards from their
			# graveyard": a player slot, then 0-3 cards bound to THAT player's
			# graveyard by a sibling filter (Drafna's Restoration's shape).
			c.spell(PlayerSlot.new())
			c.spell(ShuffleBack.new())
			c.spell(DrawEffect.new(1))
			c.with_graveyard_trigger(TriggeredAbility.new(Mtg.EventType.PUT_INTO_GRAVEYARD_FROM_LIBRARY, _blessing_milled,
				"When this card is put into your graveyard from your library, shuffle your graveyard into your library.", _this_card_milled))
		_: return false
	return true


# --------------------------------------------------------------- helpers --

static func _from_graveyard(desc: String, filter: Callable) -> ReturnFromGraveyardEffect:
	var effect := ReturnFromGraveyardEffect.new()
	effect.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, desc, filter)
	return effect

static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _artifact_or_enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)
static func _instant_or_sorcery(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.INSTANT) or i.is_type(Mtg.CardType.SORCERY)
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _damaged_this_turn(i: CardInstance) -> bool: return not i.damaged_by_this_turn.is_empty()

static func _same_ref(a: TargetRef, b: TargetRef) -> bool:
	if a.is_player or b.is_player: return a.is_player and b.is_player and a.player_id == b.player_id
	return a.instance_id == b.instance_id

static func _distinct(_g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
	for ref in earlier:
		if ref != null and _same_ref(ref, candidate): return false
	return true

static func _creature_cards(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].graveyard:
		if i.is_creature(): n += 1
	return n

## The 4-damage mode when an opposing flyer it kills is on the table.
static func _thunderbolt_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].battlefield:
		if i.is_creature() and _flying(i) and i.cur_toughness - i.damage <= 4: return 1
	return 0

static func _paradigm(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for card in g.players[pid].library.duplicate():
		g.exile_library_card(card)
	g.shuffle_graveyard_into_library(pid)

## The CASTER looks and chooses (the hand is revealed to them alone); the
## second card chosen ends on top (the order is theirs, CR 401.4).
static func _memories(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var hand: Array[CardInstance] = g.players[who].hand.duplicate()
	var names: Array = []
	for i in hand: names.append(i.data.card_name)
	g.reveal_information(pid, "Agonizing Memories — %s's hand" % g.players[who].player_name, names)
	var picks: Array[CardInstance] = []
	for n in mini(2, hand.size()):
		var pick := g.agents[pid].choose_card(g, pid, hand,
			"Agonizing Memories: choose a card to put on top of its owner's library (the second card chosen ends on top)")
		if pick == null or not hand.has(pick): pick = hand[0]
		picks.append(pick)
		hand.erase(pick)
	for pick in picks: g.put_from_hand_on_top_of_library(pick)

static func _bury(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for n in 3:
		var card := g.pick_from_library(pid, _creature_card, "Buried Alive: search for a creature card to put into your graveyard (%d of up to 3)" % (n + 1))
		if card == null: break
		g.put_into_graveyard(card)

static func _creature_card(i: CardInstance) -> bool: return i.is_creature()

static func _must_attack(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
	g._rec(i, &"must_attack_this_turn")
	i.must_attack_this_turn = true

## Counted for both seats first, then drawn in APNAP order (CR 101.4).
static func _resurgence(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var counts := {}
	for p in g.players: counts[p.id] = _creature_cards(g, p.id)
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		if int(counts[who]) > 0: g.draw_cards(who, int(counts[who]))

static func _instant_or_sorcery_card(_g: MtgGame, _pid: int, data: CardData) -> bool:
	return data.is_type(Mtg.CardType.INSTANT) or data.is_type(Mtg.CardType.SORCERY)

static func _not_mana(_g: MtgGame, _pid: int, _inst: CardInstance, _ability: Variant, is_mana: bool) -> bool:
	return not is_mana

## Until end of turn (both E4 floating bans are emptied at cleanup); mana
## abilities stay usable, exactly as printed.
static func _abeyance(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.add_floating_play_ban(t.player_id, _instant_or_sorcery_card, "Abeyance")
	g.add_floating_activation_ban(t.player_id, _not_mana, "Abeyance")

## Counted as it resolves, OWNER-keyed: creatures put into YOUR graveyard
## (a stolen creature of theirs that died went to theirs). The opponent
## picks the victims one by one and they are sacrificed together.
static func _justice(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var count := g.players[pid].creatures_to_graveyard_this_turn
	var choices: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature(): choices.append(i)
	choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power + a.cur_toughness + a.data.cost.mana_value() < b.cur_power + b.cur_toughness + b.data.cost.mana_value())
	var picks: Array[CardInstance] = []
	for n in mini(count, choices.size()):
		var pick := g.agents[who].choose_card(g, who, choices, "Urborg Justice: sacrifice a creature (%d of %d)" % [n + 1, count], false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		picks.append(pick)
		choices.erase(pick)
	g.begin_simultaneous()
	for pick in picks: g.sacrifice_permanent(pick)
	g.end_simultaneous()

static func _this_card_milled(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.get("instance") == s

static func _blessing_milled(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.shuffle_graveyard_into_library(s.owner_id)

static func _vitalize(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.players[pid].battlefield.duplicate():
		if i.is_creature() and i.tapped: g.untap_permanent(i)


# --------------------------------------------------------------- effects --

## "You gain N life for each <thing>", counted as the spell resolves.
class LifePerCount extends GainLifeEffect:
	var what: String
	var each: int
	var line: String
	func _init(counted: String, per: int, text: String) -> void:
		super(0)
		what = counted
		each = per
		line = text
	func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef, _x := 0) -> void:
		var n := 0
		if what == "hand":
			n = game.players[controller].hand.size()
		else:
			for i in game.players[controller].graveyard:
				if i.is_creature(): n += 1
		if n * each > 0: game.adjust_life(controller, n * each)
	func describe() -> String:
		return line

## Gaea's Blessing's first slot: the player whose graveyard is recycled.
class PlayerSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
		helpful()
	func resolve(_game: MtgGame, _source: CardInstance, _controller: int, _target: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "target player"

## "...shuffles up to three target cards from their graveyard into their
## library": the legal cards go in and THAT player shuffles — even with no
## card chosen. The player comes from the spell's first slot.
class ShuffleBack extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD, "target card from that player's graveyard") \
			.with_sibling_filter(_in_that_players_graveyard, TargetSpec.WHY["owner"])
		target_min = 0
		target_max = 3
		helpful()
	func resolve_multi(game: MtgGame, _source: CardInstance, _controller: int, targets: Array, _x := 0) -> void:
		for ref in targets:
			var card := game.find_instance(ref.instance_id)
			if card != null and card.zone == Mtg.Zone.GRAVEYARD: game.return_from_graveyard_to_library_top(card)
		for ref in game.current_targets():
			if ref.is_player:
				game.shuffle_library(ref.player_id)
				return
	func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef, x := 0) -> void:
		resolve_multi(game, source, controller, [], x)
	func describe() -> String:
		return "that player shuffles up to three target cards from their graveyard into their library"
	static func _in_that_players_graveyard(g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
		var inst := g.find_instance(candidate.instance_id)
		return inst != null and not earlier.is_empty() and earlier[0].is_player and inst.owner_id == earlier[0].player_id

## "You lose X life." — the X the spell was cast for.
class LoseXLife extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef, x_value := 0) -> void:
		if x_value > 0: game.adjust_life(controller, -x_value)
	func describe() -> String:
		return "you lose X life"
