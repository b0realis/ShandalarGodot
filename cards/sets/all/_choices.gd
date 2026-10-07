extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const R := preload("res://cards/sets/all/_resources.gd")
const S := preload("res://cards/sets/all/_spells.gd")
const O := preload("res://cards/sets/hml/_oyster_redirect.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Fatal Lore", "Library of Lat-Nam", "Misfortune":
			# SIMPLIFIED: opponent chooses at resolution, not announcement.
			c.oracle_text += "\nSIMPLIFIED: the opponent chooses the mode as this spell resolves."
			if c.card_name == "Fatal Lore": c.oracle_text += " Its creatures are chosen then, with normal targeting restrictions."
			c.spell(F.Action.new(_opponent_choice, "opponent chooses this spell's outcome on resolution", null, true))
		"Lim-Dûl's Vault": c.spell(F.Action.new(_vault, "look at five, optionally pay 1 life and repeat; shuffle the rest and order those five on top", null, true))
		"Phyrexian Portal": c.activated(F._ability("{3}", false, F.Action.new(_portal, "opponent divides your top ten into two hidden piles; exile one and search the other", TargetSpec.opponent(), true)))
		"Lodestone Bauble":
			var spec := TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD, "target basic land card", R._basic).with_sibling_filter(_same_owner, "all cards must be from one player's graveyard")
			spec.compare_within_group = true
			c.activated(F._ability("{1}", true, Bauble.new(spec)).with_sacrifice_cost())
		"Primitive Justice":
			c.with_extra_cost_per_target(1)
			c.extra_target_color_mask = Mtg.ManaColor.R | Mtg.ManaColor.G
			c.spell(Justice.new())
		"Taste of Paradise":
			c.repeated_additional_cost = "{1}{G}"
			c.spell(Paradise.new())
		"Undergrowth":
			var plain := PreventCombatDamageEffect.new()
			var selective := SelectiveFog.new()
			c.modes = [{"label": "Pay {G}: prevent all combat damage", "effects": [plain]}, {"label": "Pay additional {2}{R}: red creatures still deal combat damage", "effects": [selective], "payment": {"cost": ManaCost.parse("{2}{R}{G}")}}]
		"Phelddagrif":
			for pair in [[Mtg.ManaColor.G, "{G}"], [Mtg.ManaColor.W, "{W}"], [Mtg.ManaColor.U, "{U}"]]: c.activated(F._ability(pair[1], false, F.Action.new(_pheld.bind(int(pair[0])), "gain an ability or return to hand; target opponent benefits", TargetSpec.opponent(), true)))
		"Splintering Wind": c.activated(F._ability("{2}{G}", false, Splinter.new()))
		_: return false
	return true

static func _opponent_choice(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var other := 1 - pid
	if s.data.card_name == "Library of Lat-Nam":
		var choice := g.agents[other].choose_option(g, other, ["Caster draws three next upkeep", "Caster searches for any card"], "Library of Lat-Nam — choose", 1)
		if choice == 0: DelayedDrawEffect.new(3).resolve(g, s, pid, null)
		else: _tutor(g, pid, g.players[pid].library.duplicate(), "Search your library for a card", false)
	elif s.data.card_name == "Misfortune":
		var choice := g.agents[other].choose_option(g, other, ["Caster's creatures get +1/+1 counters; caster gains 4 life", "Your creatures get -1/-1 counters; take 4 damage"], "Misfortune — choose", 0)
		var who := pid if choice == 0 else other
		g.begin_simultaneous()
		for i in g.players[who].battlefield.duplicate():
			if i.is_creature(): g.add_counters(i, "+1/+1" if choice == 0 else "-1/-1")
		if choice == 0: g.adjust_life(pid, 4)
		else: g.deal_damage(s, TargetRef.player(other), 4)
		g.end_simultaneous()
	else:
		var choice := g.agents[other].choose_option(g, other, ["Caster draws three cards", "Caster destroys up to two of your creatures; you may draw up to three cards"], "Fatal Lore — choose", 0 if g.players[other].creatures().size() > 1 else 1)
		if choice == 0:
			g.draw_cards(pid, 3)
			return
		var candidates: Array[CardInstance] = []
		var spec := TargetSpec.creature()
		for ref in spec.legal_targets(g, s):
			var card := g.find_instance(ref.instance_id)
			if card.controller_id == other: candidates.append(card)
		var selected: Array[CardInstance] = []
		for n in mini(2, candidates.size()):
			var card := g.agents[pid].choose_card(g, pid, candidates, "Fatal Lore: choose a creature to destroy (optional)", true)
			if card == null or not candidates.has(card): break
			selected.append(card)
			candidates.erase(card)
		g.begin_simultaneous()
		for card in selected: g.destroy(card, false)
		g.end_simultaneous()
		S._draw_up_to(g, s, null, other, 3)

static func _tutor(g: MtgGame, pid: int, cards: Array[CardInstance], prompt: String, optional := true) -> void:
	var pick := g.agents[pid].choose_card(g, pid, cards, prompt, optional)
	if pick != null and cards.has(pick): g.library_card_to_hand(pick)
	g.shuffle_library(pid)
static func _top(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	var library := g.players[pid].library
	for n in mini(count, library.size()): cards.append(library[library.size() - n - 1])
	return cards
static func _ordered(g: MtgGame, pid: int, cards: Array[CardInstance], prompt: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var remaining := cards.duplicate()
	while not remaining.is_empty():
		var pick := g.agents[pid].choose_card(g, pid, remaining, prompt)
		if pick == null or not remaining.has(pick): pick = remaining[0]
		result.append(pick)
		remaining.erase(pick)
	return result
## Lim-Dûl's Vault. Each look is shown to the caster alone (a rule-
## authorized reveal, carried on the question that follows it), then a
## yes/no: pay 1 life to bottom these and look at the next five? (Campaign
## 2026-10, w2-10: the look used to be an optional card pick whose CANCEL
## meant "dig" — a heuristic seat, which always picks a card, never dug,
## and kept five Islands on top of a flooded board.) The hint is
## [method _vault_digs].
static func _vault(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards := _top(g, pid, 5)
	var looks := 0
	while not cards.is_empty():
		looks += 1
		var names: Array = []
		for card in cards: names.append(card.data.card_name)
		g.reveal_information(pid, "Lim-Dûl's Vault — look %d, the top %d card(s), top first" % [looks, cards.size()], names)
		# Paying 1 life needs 1 life to pay (CR 119.4).
		if g.players[pid].life < 1 or not g.agents[pid].choose_yes_no(g, pid,
				"Lim-Dûl's Vault: pay 1 life to put these cards on the bottom of your library and look at the next five?",
				_vault_digs(g, pid, cards, looks)):
			break
		g.adjust_life(pid, -1)
		for card in _ordered(g, pid, cards, "Choose the next card to put on the bottom"): g.put_on_bottom_of_library(card)
		cards = _top(g, pid, 5)
	# Shuffle with the last five in place, then lift them to the top through
	# the engine (hard rule 2, 2026-10-03): they used to be erased from the
	# library array here and appended back, in no zone while their order was
	# asked. The last one moved ends on top, so move them in reverse.
	g.shuffle_library(pid)
	var ordered := _ordered(g, pid, cards, "Choose the next card from the top")
	ordered.reverse()
	for card in ordered: g.move_library_card_to_top(card)
## The HINT for another look: only while the five hold nothing the caster
## can use — no nonland card, and no land while it has fewer than five in
## play — its life is comfortable (above 5), the library holds more than
## these five, and it has dug fewer than three times. Its own five
## cards, board and life only (docs/fair-play.md).
static func _vault_digs(g: MtgGame, pid: int, cards: Array[CardInstance], looks: int) -> bool:
	if looks > 3 or g.players[pid].life <= 5 or g.players[pid].library.size() <= cards.size():
		return false
	var lands := 0
	for perm in g.players[pid].battlefield:
		if perm.is_land(): lands += 1
	for card in cards:
		if not card.data.is_land() or lands < 5:
			return false
	return true
static func _portal(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if g.players[pid].library.size() < 10: return
	var rest := _top(g, pid, 10)
	# Show the authorized ten BEFORE the opponent decides pile sizes.
	# The caster never receives these candidates and still chooses blindly.
	g.agents[t.player_id].choose_card(g, t.player_id, rest, "Inspect these ten cards; select any card to continue to pile sizes")
	var first: Array[CardInstance] = []
	var sizes: Array[String] = []
	for count in 11: sizes.append("%d cards in pile 1; %d in pile 2" % [count, 10 - count])
	var size := g.agents[t.player_id].choose_option(g, t.player_id, sizes, "Choose the pile sizes", 5)
	for unused in clampi(size, 0, 10):
		var pick := g.agents[t.player_id].choose_card(g, t.player_id, rest, "Choose a card for pile 1", false, true)
		if pick == null or not rest.has(pick): pick = rest[0]
		first.append(pick)
		rest.erase(pick)
	var chosen := g.agents[pid].choose_option(g, pid, ["Exile pile 1 (%d cards)" % first.size(), "Exile pile 2 (%d cards)" % rest.size()], "Choose without looking at either pile", 0 if first.size() <= rest.size() else 1)
	var gone: Array = first if chosen == 0 else rest
	var kept: Array[CardInstance] = rest if chosen == 0 else first
	for card in gone: g.exile_library_card(card)
	_tutor(g, pid, kept, "Search the remaining pile for a card", false)
static func _same_owner(g: MtgGame, _s: CardInstance, ref: TargetRef, earlier: Array) -> bool:
	return earlier.is_empty() or g.find_instance(ref.instance_id).owner_id == g.find_instance(earlier[0].instance_id).owner_id
class Bauble extends S.GraveTop:
	func _init(spec: TargetSpec) -> void: super(spec, 4)
	func resolve_multi(g: MtgGame, s: CardInstance, pid: int, targets: Array, x := 0) -> void:
		var who := -1 if targets.is_empty() else g.find_instance(targets[0].instance_id).owner_id
		super(g, s, pid, targets, x)
		if who >= 0: DelayedDrawEffect.new().resolve(g, s, who, null)
class Justice extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact))
		target_max = -1
	static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	func resolve_multi(g: MtgGame, s: CardInstance, pid: int, targets: Array, x := 0) -> void:
		g.begin_simultaneous()
		for t in targets: super.resolve(g, s, pid, t, x)
		# Life is for payments, not successful destruction or surviving targets.
		var spent: Dictionary = g.cost_paid("restricted_x_paid", {})
		g.adjust_life(pid, int(spent.get(Mtg.ManaColor.G, 0)))
		g.end_simultaneous()
class Paradise extends GainLifeEffect:
	func _init() -> void: super(3)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, x := 0) -> void: g.adjust_life(pid, 3 + 3 * x)
class SelectiveFog extends PreventCombatDamageEffect:
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		g.continuous.add_floating_static(s, StaticAbility.new(_prevent_nonred, "Prevent combat damage from nonred creatures."), ContinuousEffects.Duration.END_OF_TURN)
		g.recalculate()
	static func _prevent_nonred(g: MtgGame, _s: CardInstance) -> void:
		for i in g.all_battlefield():
			if i.is_creature() and (i.cur_colors & Mtg.ManaColor.R) == 0: i.cur_prevent_combat_damage_dealt = true
static func _pheld(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int, color: int) -> void:
	if color == Mtg.ManaColor.U:
		if B.live_source(g, s): g.return_to_hand(s)
		if g.agents[t.player_id].choose_yes_no(g, t.player_id, "Draw a card from Phelddagrif?", not g.players[t.player_id].library.is_empty()): g.draw_cards(t.player_id, 1)
	else:
		if B.live_source(g, s) and g.is_present(s): g.continuous.add_until_eot_keywords(s.id, [Mtg.Keyword.TRAMPLE if color == Mtg.ManaColor.G else Mtg.Keyword.FLYING])
		if color == Mtg.ManaColor.W: g.adjust_life(t.player_id, 2)
		else: g.create_token(t.player_id, CardData.new("Hippo", "", Mtg.CardType.CREATURE).pt(1, 1).with_colors(Mtg.ManaColor.G).with_subtypes(["hippo"]))
		g.recalculate()
class Splinter extends DamageEffect:
	func _init() -> void:
		super(1)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var token := CardData.new("Splinter", "", Mtg.CardType.CREATURE).pt(1, 1).with_colors(Mtg.ManaColor.G).with_subtypes(["splinter"]).with_keywords([Mtg.Keyword.FLYING])
		CumulativeUpkeep.attach(token, "{G}")
		var made := g.create_token(pid, token)
		for i in made:
			g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _burst.bind(pid), "Splinter deals 1 damage to you and each creature you control.", _left.bind(i.id, i.layer_timestamp)), pid, i)
	static func _left(_g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int) -> bool: return e.data.instance.id == id and e.data.instance.layer_timestamp == stamp
	static func _burst(g: MtgGame, s: CardInstance, _e: GameEvent, who: int) -> void:
		g.begin_simultaneous()
		g.deal_damage(s, TargetRef.player(who), 1)
		for i in g.players[who].battlefield.duplicate():
			if i.is_creature(): g.deal_damage(s, TargetRef.card(i), 1)
		g.end_simultaneous()
