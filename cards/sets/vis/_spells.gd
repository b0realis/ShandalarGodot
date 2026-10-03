extends RefCounted
## Visions (_spells, Pack 8). Instants and sorceries: one-shot spell effects,
## modes, X spells and their targets.
##
## Same conventions as the Mirage module (cards/sets/mir/_spells.gd, whose
## predicate class P this one shares): typed effects first, card-local
## subclasses of the nearest typed effect, every choice the resolving
## seat's own question with a public-information hint.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_spells.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Hope Charm":
			c.mode("Target creature gains first strike until end of turn", [PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE])])
			c.mode("Target player gains 2 life", [GainLifeEffect.new(2).target_player()])
			c.mode("Destroy target Aura", [DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Aura", _aura))])
			c.with_ai_mode(_hope_mode)
		"Miraculous Recovery": c.spell(Recovery.new())
		# "Prevent the next 5 damage ... to any number of targets, divided as
		# you choose": each target's share rides on its TargetRef (CR 601.2d).
		"Remedy": c.spell(PreventDamageEffect.new(0).divided(5))
		# "If an artifact or creature spell is countered this way, put that
		# card onto the battlefield under your control instead" — any other
		# spell goes to its owner's graveyard.
		"Desertion": c.spell(CounterEffect.new().to_battlefield_for_caster())
		"Solfatara":
			c.spell(F.Action.new(_solfatara, "target player can't play lands this turn", TargetSpec.player()))
			c.spell(DelayedDrawEffect.new())
		"Retribution of the Meek": c.spell(DestroyAllEffect.new("all creatures with power 4 or greater", _power_four, false))
		"Warrior's Honor": c.spell(MassPumpEffect.new(1, 1, "creatures you control").yours_only())
		"Foreshadow":
			c.spell(F.Action.new(_foreshadow, "name a card; target opponent mills a card, and if it has that name you draw a card", TargetSpec.opponent()))
			c.spell(DelayedDrawEffect.new())
		"Impulse": c.spell(ImpulseEffect.new())
		"Inspiration": c.spell(DrawEffect.new(2).target_player())
		"Funeral Charm":
			c.mode("Target player discards a card", [TargetDiscard.new()])
			c.mode("Target creature gets +2/-1 until end of turn", [PumpEffect.new(2, -1)])
			c.mode("Target creature gains swampwalk until end of turn", [GrantLandwalkEffect.new(["swamp"])])
			c.with_ai_mode(_funeral_mode)
		"Hearth Charm":
			c.mode("Destroy target artifact creature", [DestroyEffect.new(TargetSpec.creature("target artifact creature", _artifact)
				.because(TargetSpec.WHY["artifact_creature"]))])
			c.mode("Attacking creatures get +1/+0 until end of turn", [AttackersPump.new()])
			var sneak := PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])
			sneak.target_spec = TargetSpec.creature("target creature with power 2 or less", _power_two_or_less) \
				.because(TargetSpec.WHY["power"])
			c.mode("Target creature with power 2 or less can't be blocked this turn", [sneak])
			c.with_ai_mode(_hearth_mode)
		"Creeping Mold": c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact, enchantment, or land", _artifact_enchantment_or_land)))
		"Emerald Charm":
			c.mode("Untap target permanent", [UntapEffect.new()])
			c.mode("Destroy target non-Aura enchantment", [DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target non-Aura enchantment", _non_aura_enchantment))])
			c.mode("Target creature loses flying until end of turn", [LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying")])
			c.with_ai_mode(_emerald_mode)
		"Feral Instinct": c.spell(PumpEffect.new(1, 1)).spell(DelayedDrawEffect.new())
		"Simoon": c.spell(Simoon.new())
		_: return false
	return true


static func _aura(i: CardInstance) -> bool: return i.is_aura()
static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _power_four(i: CardInstance) -> bool: return i.is_creature() and i.cur_power >= 4
static func _power_two_or_less(i: CardInstance) -> bool: return i.cur_power <= 2
static func _non_aura_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ENCHANTMENT) and not i.is_aura()
static func _artifact_enchantment_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT) or i.is_land()


## Solfatara: an until-end-of-turn play ban on the target player's land
## drops (MtgGame.add_floating_play_ban; cleared at cleanup, CR 514.2).
static func _solfatara(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.add_floating_play_ban(t.player_id, _is_land_card, "Solfatara")

static func _is_land_card(_g: MtgGame, _pid: int, data: CardData) -> bool: return data.is_land()


# ================================================================ AI modes

static func _hope_mode(g: MtgGame, pid: int) -> int:
	for i in g.all_battlefield():
		if _aura(i) and i.controller_id != pid: return 2
	return 1

static func _funeral_mode(g: MtgGame, pid: int) -> int:
	return 0 if not g.players[g.opponent_of(pid)].hand.is_empty() else 1

static func _hearth_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].creatures():
		if _artifact(i): return 0
	for id in g.combat.attackers:
		var i := g.find_instance(int(id))
		if i != null and i.controller_id == pid: return 1
	return 2

static func _emerald_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].battlefield:
		if _non_aura_enchantment(i): return 1
	for i in g.players[g.opponent_of(pid)].creatures():
		if i.has_keyword(Mtg.Keyword.FLYING): return 2
	return 0


# ================================================================== classes

class Recovery extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		to_battlefield()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.GRAVEYARD: return
		super(g, s, pid, t, x)
		if i.zone == Mtg.Zone.BATTLEFIELD: g.add_counters(i, "+1/+1")
	func describe() -> String:
		return "return target creature card from your graveyard to the battlefield with a +1/+1 counter on it"


## "Target player discards a card" — THEIR choice (Disrupting Scepter's shape).
class TargetDiscard extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		if g.players[who].hand.is_empty(): return
		g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))
	func describe() -> String:
		return "target player discards a card (their choice)"


## "Attacking creatures get +1/+0" — every attacking creature on either
## side, fixed as it resolves.
class AttackersPump extends MassPumpEffect:
	func _init() -> void:
		super(1, 0, "attacking creatures")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		for i in g.all_battlefield():
			if i.is_creature() and g.combat.attackers.has(i.id):
				g.continuous.add_until_eot_pump(i.id, power, toughness, granted_keywords)
		g.log_line("%s: attacking creatures get +1/+0 until end of turn" % s.data.card_name)
		g.recalculate()


class Simoon extends DamageAllEffect:
	func _init() -> void:
		super(1, "each creature target opponent controls")
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var victims: Array[CardInstance] = g.players[t.player_id].creatures()
		g.begin_simultaneous()
		for i in victims: g.deal_damage(s, TargetRef.card(i), amount)
		g.end_simultaneous()
	func describe() -> String:
		return "deals 1 damage to each creature target opponent controls"


## The names a seat may call for Foreshadow: the TARGET OPPONENT's
## decklist (the owner's naming ruling, 2026-09-07), most copies not yet
## seen first. Only PUBLIC zones are subtracted — the opponent's hand and
## the order of their library are never read (fair play, CONTRIBUTING
## rule 8), which is why this is not Petra Sphinx's list (that one is the
## chooser's own deck and counts their own hand).
static func _nameable(g: MtgGame, who: int) -> Array[String]:
	var left := {}
	for n in g.players[who].deck_names: left[n] = int(left.get(n, 0)) + 1
	for p in g.players:
		for zone in [p.battlefield, p.graveyard, p.exile]:
			for i in zone:
				if i.is_token or i.face_down or i.owner_id != who: continue
				if left.has(i.data.card_name): left[i.data.card_name] = maxi(int(left[i.data.card_name]) - 1, 0)
	var names: Array[String] = []
	for n in left: names.append(String(n))
	names.sort_custom(func(a: String, b: String) -> bool:
		if int(left[a]) != int(left[b]): return int(left[a]) > int(left[b])
		return a < b)
	return names


static func _foreshadow(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var names := _nameable(g, who)
	var named := ""
	if not names.is_empty():
		var pick := g.agents[pid].choose_option(g, pid, names, "Foreshadow: name a card", 0)
		if pick >= 0 and pick < names.size(): named = names[pick]
	g.log_line("%s names %s" % [g.players[pid].player_name, named if named != "" else "a card"])
	var library := g.players[who].library
	if library.is_empty(): return
	var top: CardInstance = library.back()
	g.mill(who, 1)
	if named != "" and top.zone == Mtg.Zone.GRAVEYARD and top.data.card_name == named:
		g.draw_cards(pid, 1)


## Impulse: one card of the top four, the rest to the bottom in the order
## the caster chooses. A DrawEffect for one in the AI's eyes — what it nets
## is a card, chosen.
class ImpulseEffect extends DrawEffect:
	func _init() -> void:
		super(1)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var library := g.players[pid].library
		var n := mini(4, library.size())
		if n == 0: return
		var seen: Array[CardInstance] = []
		for k in n: seen.append(library[library.size() - 1 - k])
		var names: Array = []
		for card in seen: names.append(card.data.card_name)
		g.reveal_information(pid, "Impulse — the top %d card(s) of your library" % n, names)
		var ranked: Array[CardInstance] = M.P.best_first(g, seen)
		var keep := g.agents[pid].choose_card(g, pid, ranked, "Impulse: choose a card to put into your hand")
		if keep == null or not ranked.has(keep): keep = ranked[0]
		g.library_card_to_hand(keep)
		seen.erase(keep)
		while not seen.is_empty():
			var next: CardInstance = seen[0] if seen.size() == 1 else g.agents[pid].choose_card(g, pid, seen,
				"Impulse: choose the next card to put on the bottom of your library")
			if next == null or not seen.has(next): next = seen[0]
			g.put_on_bottom_of_library(next)
			seen.erase(next)
	func describe() -> String:
		return "look at the top four cards of your library; put one into your hand and the rest on the bottom in any order"
