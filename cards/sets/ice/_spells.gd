extends RefCounted
## Spell patterns. Choices use the resolving seat's DecisionAgent, never
## random global state or an AI-only look into a hidden library.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Brainstorm": c.spell(Brainstorm.new())
		"Clairvoyance":
			c.spell(load("res://cards/sets/2ed/glasses_of_urza.gd").PeekEffect.new())
			c.spell(DelayedDrawEffect.new())
		"Portent":
			c.spell(load("res://cards/sets/2ed/natural_selection.gd").NaturalSelectionEffect.new())
			c.spell(DelayedDrawEffect.new())
		"Diabolic Vision": c.spell(F.Action.new(_vision, "look at five cards, keep one and order the rest", null, true))
		"Stunted Growth": c.spell(F.Action.new(_stunted, "target player puts three cards from hand on top of their library", TargetSpec.player()))
		"Nature's Lore": c.spell(SearchLibraryEffect.new("a Forest card", _forest).to_battlefield())
		"Altar of Bone":
			c.with_additional_sacrifice("a creature", _creature)
			c.spell(SearchLibraryEffect.new("a creature card", _creature))
		"Songs of the Damned": c.spell(Songs.new())
		"Spoils of Evil": c.spell(F.Action.new(_spoils, "add mana and gain life for artifacts and creatures in target opponent's graveyard", TargetSpec.opponent(), true))
		"Gravebind":
			c.spell(F.Action.new(_ban_regeneration, "target creature can't be regenerated this turn", TargetSpec.creature()))
			c.spell(DelayedDrawEffect.new())
		"Incinerate": c.spell(Incinerate.new())
		"Lava Burst": c.spell(LavaBurst.new())
		"Hydroblast", "Pyroblast":
			var color := Mtg.ManaColor.R if c.card_name == "Hydroblast" else Mtg.ManaColor.U
			c.mode("Counter target spell if it has the required color", [ConditionalCounter.new(color)])
			c.mode("Destroy target permanent if it has the required color", [ConditionalDestroy.new(color)])
			c.with_ai_mode(_proactive_blast)
		"Essence Filter":
			c.mode("Destroy all enchantments", [DestroyAllEffect.new("all enchantments", _enchantment)])
			c.mode("Destroy all nonwhite enchantments", [DestroyAllEffect.new("all nonwhite enchantments", _nonwhite_enchantment)])
			c.with_ai_mode(_filter_mode)
		"Essence Vortex": c.spell(F.Action.new(_vortex, "destroy target creature unless its controller pays life equal to its toughness", TargetSpec.creature()))
		"Word of Blasting":
			c.spell(F.Action.new(_blasting, "destroy target Wall without regeneration and damage its controller", TargetSpec.creature("target Wall", _wall).only_walls()))
		"Word of Undoing": c.spell(Undoing.new())
		"Vertigo": c.spell(Vertigo.new())
		"Foxfire":
			c.spell(Foxfire.new())
			c.spell(DelayedDrawEffect.new())
		"Warning": c.spell(PreventCombatDamageEffect.new().by_target_creature(TargetSpec.creature("target attacking creature").with_game_filter(_attacking)))
		"Panic":
			c.castable_only_when(_before_blockers)
			c.spell(F.Action.new(_panic, "target creature can't block this turn", TargetSpec.creature()))
			c.spell(DelayedDrawEffect.new())
		"Battle Frenzy":
			c.spell(MassPumpEffect.new(1, 1, "your green creatures").yours_only().with_filter(_green))
			c.spell(MassPumpEffect.new(1, 0, "your nongreen creatures").yours_only().with_filter(_nongreen))
		"Rally": c.spell(CombatPump.new(false))
		"Stampede": c.spell(CombatPump.new(true))
		"Mind Warp": c.spell(MindWarp.new())
		"Fiery Justice":
			c.spell(DamageEffect.new(5).any_target().divided(5))
			var gain := GainLifeEffect.new(5)
			gain.target_spec = TargetSpec.opponent()
			c.spell(gain)
		"Forgotten Lore": c.spell(F.Action.new(_forgotten, "target opponent chooses a card to return from your graveyard", TargetSpec.opponent(), true))
		_: return false
	return true

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _forest(i: CardInstance) -> bool: return i.has_subtype("forest")
static func _wall(i: CardInstance) -> bool: return i.has_subtype("wall")
static func _green(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.G) != 0
static func _nongreen(i: CardInstance) -> bool: return not _green(i)
static func _enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func _nonwhite_enchantment(i: CardInstance) -> bool: return _enchantment(i) and (i.cur_colors & Mtg.ManaColor.W) == 0
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _proactive_blast(_g: MtgGame, _pid: int) -> int: return 1
static func _filter_mode(g: MtgGame, pid: int) -> int:
	var balance := 0
	for i in g.all_battlefield():
		if _enchantment(i) and (i.cur_colors & Mtg.ManaColor.W) != 0:
			balance += (1 if i.controller_id != pid else -1) * maxi(1, i.data.cost.mana_value())
	return 0 if balance > 0 else 1
static func _before_blockers(g: MtgGame, _pid: int) -> String:
	return "Cast only during combat before blockers are declared" if not Mtg.is_combat_step(g.current_step()) or g.current_step() >= Mtg.Step.DECLARE_BLOCKERS else ""

## Pick the eventual top card LAST when moving hand cards individually.
static func _hand_top(g: MtgGame, pid: int, count: int) -> void:
	for _i in mini(count, g.players[pid].hand.size()):
		var choices: Array[CardInstance] = g.players[pid].hand.duplicate()
		var card := g.agents[pid].choose_card(g, pid, choices,
			"Put a card from your hand on top of your library (last choice will be on top)", false, true)
		if card != null and choices.has(card): g.put_from_hand_on_top_of_library(card)

static func _vision(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var pile: Array[CardInstance] = g.players[pid].library
	var left: Array[CardInstance] = []
	for i in mini(5, pile.size()): left.append(pile[pile.size() - 1 - i])
	if left.is_empty(): return
	var keep := g.agents[pid].choose_card(g, pid, left, "Put one of these five cards into your hand")
	if keep == null or not left.has(keep): return
	left.erase(keep)
	var ordered: Array[CardInstance] = [keep]
	while not left.is_empty():
		var card := g.agents[pid].choose_card(g, pid, left, "Order the remaining cards, next draw first", false, false, true)
		if card == null or not left.has(card): return
		left.erase(card)
		ordered.append(card)
	g.reorder_top_of_library(pid, ordered)
	g.top_of_library_to_hand(pid)

static func _stunted(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	_hand_top(g, t.player_id, 3)
static func _spoils(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var count := 0
	for i in g.players[t.player_id].graveyard:
		if i.is_creature() or i.is_type(Mtg.CardType.ARTIFACT): count += 1
	g.players[pid].mana_pool.add(Mtg.ManaColor.C, count)
	g.adjust_life(pid, count)
static func _ban_regeneration(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i != null:
		g._rec(i, &"regeneration_banned_this_turn")
		i.regeneration_banned_this_turn = true
static func _incinerated(g: MtgGame, _s: CardInstance, victim: CardInstance, _amount: int) -> void:
	_ban_regeneration(g, null, 0, TargetRef.card(victim), 0)
static func _vortex(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null: return
	var due := maxi(0, i.cur_toughness)
	var who := i.controller_id
	if g.players[who].life >= due and g.agents[who].choose_yes_no(g, who,
		"Pay %d life to save %s?" % [due, i.data.card_name], g.players[who].life > due + 3):
		g.adjust_life(who, -due)
	else: DestroyEffect.new(TargetSpec.creature(), false).resolve(g, s, who, t)
static func _blasting(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null: return
	var who := i.controller_id
	var amount := i.data.cost.mana_value()
	DestroyEffect.new(TargetSpec.creature(), false).resolve(g, s, pid, t)
	g.deal_damage(s, TargetRef.player(who), amount)
static func _panic(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_no_block.bind(t.instance_id), "Can't block this turn."), ContinuousEffects.Duration.END_OF_TURN, -1, false, t.instance_id)
	g.recalculate()
static func _no_block(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD:
		i.cur_cant_block_filter = func(_attacker: CardInstance) -> bool: return true
static func _forgotten(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var choices: Array[CardInstance] = g.players[pid].graveyard.duplicate()
	var last: CardInstance = null
	while not choices.is_empty():
		last = g.agents[t.player_id].choose_card(g, t.player_id, choices, "Choose the graveyard card to return to your opponent", false, true)
		if last == null or not choices.has(last): return
		choices.erase(last)
		# Paying again when no other card exists is legal but never beneficial;
		# it leaves the same last chosen card. Offer it with a negative hint.
		if not EffectBase.unless_paid(g, pid, ManaCost.parse("{G}"),
			"Pay {G} to reject %s and have your opponent choose again?" % last.data.card_name, not choices.is_empty()): break
	if last != null and last.zone == Mtg.Zone.GRAVEYARD: g.return_from_graveyard_to_hand(last)

class Brainstorm extends DrawEffect:
	func _init() -> void: super(3)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		load("res://cards/sets/ice/_spells.gd")._hand_top(g, pid, 2)
	func describe() -> String: return "draw three cards, then put two cards from your hand on top of your library"

class Songs extends AddManaEffect:
	func _init() -> void: super(Mtg.ManaColor.B, 0)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var count := 0
		for i in g.players[pid].graveyard:
			if i.is_creature(): count += 1
		g.players[pid].mana_pool.add(Mtg.ManaColor.B, count)

class Incinerate extends DamageEffect:
	func _init() -> void:
		super(3)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		g.watch_damage_dealt(s, load("res://cards/sets/ice/_spells.gd")._incinerated)
		super(g, s, pid, t, x)

class LavaBurst extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target().x_damage()
		unpreventable_to_creatures = true

class ConditionalCounter extends CounterEffect:
	var color: int
	func _init(value: int) -> void:
		super()
		color = value
	# The colour, and never a spell that can't be countered (CounterEffect's own test).
	func affects_spell(inst: CardInstance) -> bool: return super.affects_spell(inst) and inst != null and (inst.cur_colors & color) != 0
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null and (i.cur_colors & color) != 0: super(g, s, pid, t, x)

class ConditionalDestroy extends DestroyEffect:
	var color: int
	func _init(value: int) -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))
		color = value
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null and (i.cur_colors & color) != 0: super(g, s, pid, t, x)

class Undoing extends ReturnToHandEffect:
	func _init() -> void: super(TargetSpec.creature())
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		g.begin_simultaneous()
		for aura in g.all_battlefield().duplicate():
			if aura.attached_to == t.instance_id and aura.owner_id == pid and (aura.cur_colors & Mtg.ManaColor.W) != 0:
				g.return_to_hand(aura)
		super(g, s, pid, t, x)
		g.end_simultaneous()

class Vertigo extends DamageEffect:
	func _init() -> void:
		super(2)
		target_creature("target creature with flying", load("res://cards/sets/ice/_spells.gd")._flying)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying").resolve(g, s, pid, t)

class Foxfire extends PreventCombatDamageEffect:
	func _init() -> void:
		super()
		by_target_creature(TargetSpec.creature("target attacking creature").with_game_filter(load("res://cards/sets/ice/_spells.gd")._attacking)).and_to_target()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		g.untap_permanent(g.find_instance(t.instance_id))
		super(g, s, pid, t, x)

class CombatPump extends MassPumpEffect:
	var attackers: bool
	func _init(attacking: bool) -> void:
		attackers = attacking
		super(1, 0 if attacking else 1, "attacking creatures" if attacking else "blocking creatures", [Mtg.Keyword.TRAMPLE] if attacking else [])
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		for i in g.all_battlefield():
			if i.is_creature() and (g.combat.attackers.has(i.id) if attackers else not g.combat.attackers_blocked_by(i.id).is_empty()):
				g.continuous.add_until_eot_pump(i.id, power, toughness, granted_keywords)
		g.recalculate()

class MindWarp extends ChosenDiscardEffect:
	func _init() -> void:
		super()
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var left := candidates(g, t.player_id)
		var chosen: Array[CardInstance] = []
		for _i in mini(x, left.size()):
			var pick := g.agents[pid].choose_card(g, pid, left, "Choose a card for target player to discard")
			if pick != null and left.has(pick):
				chosen.append(pick)
				left.erase(pick)
		g.discard_cards(t.player_id, chosen)
	func describe() -> String: return "target player discards X cards of your choice"
