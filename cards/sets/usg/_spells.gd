extends RefCounted
## Urza's Saga (_spells, Pack 10). Instants and sorceries resolved by
## existing effects: one-shot spell effects, X spells, multi-target slots
## and the choices made as they resolve.
##
## Effects are TYPED wherever the engine has the shape — the fair AI reads
## them (engine/ai/effect_intent.gd) — and a card-local class subclasses the
## typed effect it most resembles (Corrupt a DamageEffect counted as it
## resolves, Disorder a DamageAllEffect that also finds its players,
## Meltdown a DestroyAllEffect reading X, Goblin Offensive a
## CreateTokenEffect reading X, Headlong Rush a MassPumpEffect over the
## attackers). A card-local effect the readers cannot price declares its
## shape through [member EffectBase.ai_role] for the Stage 4 policy.
## Targeting restrictions live in the TargetSpec, never in resolve().
##
## - Humble: "loses all abilities" is a FLOATING silencer
##   (StaticAbility.removing_all_abilities, bound to the target) — the
##   strip happens in layer 6 at Humble's timestamp, so a grant made
##   earlier goes and one made later (a Flight cast afterwards) survives
##   (CR 613.7); the base 0/1 is a layer-7b setter, so an Aura's +1/+2 and
##   a Giant Growth still apply over it. Both end at cleanup, and both are
##   forgotten if the creature leaves (CR 400.7).
## - Planar Birth, Hibernation, Sunder: every card or permanent moves in
##   one event — the departures through MtgGame.depart_together (each
##   leaves as the board stood before any did), the arrivals through
##   MtgGame.put_onto_battlefield_together (Pack 10 E10: one moment, every
##   "enters" announced after all have arrived).
## - Exhume: untargeted. Each player chooses a creature card in their own
##   graveyard, APNAP (CR 101.4), before any card moves; the chosen cards
##   then arrive together (E10), each under the player who chose it — so
##   a "whenever another creature enters" among them sees the other.
## - Redeem: "up to two" — zero targets is a legal cast (CR 601.2c). A
##   prevention spell, so it is legal in the 1997 damage window
##   ([member EffectBase.is_damage_prevention]).
## - Waylay: the three Knights are exiled by a delayed trigger at the
##   beginning of the next cleanup step (MtgGame.schedule_cleanup_action,
##   CR 514.3a), each by id and battlefield stamp.
## - Curfew: untargeted — a creature with protection or shroud may be
##   chosen. Each player chooses in APNAP order (CR 101.4) before any
##   creature moves; then they all return together, each to its OWNER's
##   hand.
## - Tolarian Winds, Windfall: the count is the cards DISCARDED — a card
##   Library of Leng puts on top of the library instead was still
##   discarded (Duel.hlp's own Leng ruling).
## - Befoul: "land or nonblack creature", and the destruction ignores
##   regeneration (CR 701.15d).
## - Corrupt: X is the Swamps you control as it resolves (the live Swamp
##   subtype); the life is the damage actually DEALT, answered when the
##   damage lands (so the 1997 window and prevention are respected — Drain
##   Life's shape, 2ed/drain_life.gd).
## - Duress: the whole hand is revealed to the table; the caster must pick
##   a noncreature, nonland card when there is one.
## - Ill-Gotten Gains: the discards come first, so a card just discarded
##   may be returned; each player chooses in APNAP order, then the cards
##   return. The spell exiles itself as it resolves (Recall's shape).
## - Rain of Filth: a floating layer-6 grant over the lands you control as
##   it resolves (a locked set, CR 611.2c) — "Sacrifice this land: Add
##   {B}." has no {T}, so a tapped land pays too; the planner spends a
##   sacrifice row only after the tapping ones (mana_planner.gd).
## - Reprocess: any number of your artifacts, creatures and lands, chosen
##   then sacrificed in one event; a card is drawn for each.
## - Unnerve: each opponent chooses their own two cards.
## - Acidic Soil, Disorder, Fault Line, Steam Blast: one damage event
##   (CR 120.3, 704.3) — both players dying together is a draw (CR 104.4a).
##   Disorder's players are those who control a white creature as it
##   resolves, judged before any damage.
## - Falter: a rules change, not a characteristic change, so it is NOT a
##   locked set (CR 611.2c reaches only characteristics and control): any
##   creature without flying, read when blockers are declared, can't block
##   this turn — [forge] forge-gui/res/cardsfolder/f/falter.txt (commit
##   b09a3d3f) builds the same live static.
## - Gamble: the card goes to the hand BEFORE the random discard, so it may
##   be the card discarded; the library is shuffled last. The discard is
##   the spell's (Library of Leng applies).
## - Headlong Rush: the attacking creatures as it resolves (a characteristic
##   change, a locked set, CR 611.2c).
## - Meltdown: "mana value X or less" is the printed mana cost's (X = 0 on
##   the battlefield, CR 202.3e), against the spell's X.
## - Raze: the additional cost is paid after the target is chosen (CR
##   601.2c, 601.2h) — aimed at the land it then sacrifices, it fizzles.
## - Shower of Sparks: two slots; one gone still leaves the other (CR
##   608.2b). Planeswalkers do not exist here: "target player".
## - Gaea's Bounty: up to two searches for a Forest card (subtype), each
##   revealed, then one shuffle (Land Tax's shape, 4ed/land_tax.gd).
## tests/cards/test_pack_10_B1_white_blue.gd, _black.gd, _red.gd,
## _green.gd and _ai.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Congregate": c.spell(Congregate.new())
		"Humble": c.spell(Humble.new())
		"Planar Birth":
			c.spell(F.Action.new(_planar_birth,
				"return all basic land cards from all graveyards to the battlefield tapped under their owners' control") \
				.with_ai_role(&"return_all_basic_lands"))
		"Redeem": c.spell(Redeem.new())
		"Waylay": c.spell(Waylay.new())
		# ------------------------------------------------------------- blue
		"Annul": c.spell(CounterEffect.new("target artifact or enchantment spell", P.artifact_or_enchantment))
		"Catalog": c.spell(Loot.new(2))
		"Curfew":
			c.spell(F.Action.new(_curfew, "each player returns a creature they control to its owner's hand") \
				.with_ai_role(&"each_player_bounces_own_creature"))
		"Hibernation":
			c.spell(F.Action.new(_hibernation, "return all green permanents to their owners' hands") \
				.with_ai_role(&"bounce_all_of_color", {"color": Mtg.ManaColor.G}))
		"Stroke of Genius": c.spell(DrawX.new())
		"Sunder":
			c.spell(F.Action.new(_sunder, "return all lands to their owners' hands") \
				.with_ai_role(&"bounce_all_lands"))
		"Tolarian Winds": c.spell(TolarianWinds.new())
		"Windfall": c.spell(Windfall.new())
		# ------------------------------------------------------------ black
		"Befoul":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target land or nonblack creature", P.land_or_nonblack_creature), false))
		"Breach": c.spell(PumpEffect.new(2, 0, [Mtg.Keyword.FEAR]))
		"Corrupt": c.spell(Corrupt.new())
		"Duress": c.spell(RevealedDiscard.new("noncreature, nonland", P.noncreature_nonland_card))
		"Exhume": c.spell(Exhume.new())
		"Ill-Gotten Gains": c.spell(IllGottenGains.new())
		"Rain of Filth":
			c.spell(F.Action.new(_rain_of_filth,
				"until end of turn, lands you control gain \"Sacrifice this land: Add {B}.\"") \
				.with_ai_role(&"lands_sacrifice_for_black"))
		"Reprocess": c.spell(Reprocess.new())
		"Unnerve": c.spell(Unnerve.new())
		# -------------------------------------------------------------- red
		"Acidic Soil": c.spell(AcidicSoil.new())
		"Arc Lightning":
			var arc := DamageEffect.new(3).any_target().divided_among(3)
			arc.target_max = 3
			c.spell(arc)
		"Disorder": c.spell(Disorder.new())
		"Falter":
			c.spell(F.Action.new(_falter, "creatures without flying can't block this turn") \
				.with_ai_role(&"grounded_cant_block_this_turn"))
		"Fault Line":
			c.spell(DamageAllEffect.new(0, "each creature without flying", P.without_flying) \
				.x_damage().and_each_player())
		"Gamble": c.spell(Gamble.new())
		"Goblin Offensive": c.spell(XTokens.new())
		"Headlong Rush": c.spell(HeadlongRush.new())
		"Heat Ray": c.spell(DamageEffect.new(0).target_creature().x_damage())
		"Meltdown": c.spell(Meltdown.new())
		"Raze":
			c.with_additional_sacrifice("land", P.land)
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", P.land)))
		"Shower of Sparks":
			c.spell(DamageEffect.new(1).target_creature())
			c.spell(DamageEffect.new(1).target_player())
		"Steam Blast": c.spell(DamageAllEffect.new(2).and_each_player())
		# ------------------------------------------------------------ green
		"Gaea's Bounty": c.spell(GaeasBounty.new())
		"Symbiosis": c.spell(U.two_targets(PumpEffect.new(2, 2)))
		"Titania's Boon":
			c.spell(F.Action.new(_titanias_boon, "put a +1/+1 counter on each creature you control", null, true) \
				.with_ai_role(&"counter_on_each_own_creature", {"kind": "+1/+1", "count": 1}))
		"Whirlwind": c.spell(DestroyAllEffect.new("all creatures with flying", P.flying_creature))
		_: return false
	return true


# ================================================================ predicates

## Instance tests read LIVE characteristics (cur_*); a card in a hand, a
## library or a graveyard has only its printed ones (data).
class P:
	static func land(i: CardInstance) -> bool: return i.is_land()
	static func black(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) != 0
	static func white(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.W) != 0
	static func green(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.G) != 0
	static func artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	static func enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
	static func artifact_or_enchantment(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)
	static func artifact_creature_or_land(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()
	static func land_or_nonblack_creature(i: CardInstance) -> bool:
		return i.is_land() or (i.is_creature() and not black(i))
	static func flying_creature(i: CardInstance) -> bool:
		return i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING)
	static func without_flying(i: CardInstance) -> bool:
		return not i.has_keyword(Mtg.Keyword.FLYING)
	static func white_creature(i: CardInstance) -> bool: return i.is_creature() and white(i)
	static func noncreature_nonland_card(i: CardInstance) -> bool:
		return not i.data.is_creature() and not i.data.is_land()
	static func creature_card(i: CardInstance) -> bool: return i.data.is_creature()
	static func artifact_card(i: CardInstance) -> bool: return i.data.is_type(Mtg.CardType.ARTIFACT)
	static func land_card(i: CardInstance) -> bool: return i.data.is_land()
	static func basic_land_card(i: CardInstance) -> bool:
		return i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0
	## "Forest card": the Forest subtype (a nonbasic Forest counts).
	static func forest_card(i: CardInstance) -> bool:
		return i.data.is_land() and i.data.subtypes.has("forest")

	## What a permanent is worth keeping, for a chooser ranking its own:
	## a token least, then the cheapest and smallest.
	static func worth(i: CardInstance) -> int:
		if i.is_token: return -100
		return i.data.cost.mana_value() * 2 + maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0)
	static func least_worth_first(a: CardInstance, b: CardInstance) -> bool:
		var wa := worth(a)
		var wb := worth(b)
		if wa != wb: return wa < wb
		return a.id < b.id
	static func costliest_card_first(a: CardInstance, b: CardInstance) -> bool:
		var ma := a.data.cost.mana_value()
		var mb := b.data.cost.mana_value()
		if ma != mb: return ma > mb
		return a.id < b.id


# =============================================================== the shared

## Helpers the Urza's Legacy module (ulg/_spells.gd) shares.
class U:
	## "Two target creatures each …" (Symbiosis, Sick and Tired): ONE effect
	## taking two different creatures (CR 601.2c), the Ashes to Ashes shape.
	static func two_targets(e: EffectBase, desc := "two target creatures") -> EffectBase:
		e.target_spec = TargetSpec.creature(desc)
		e.target_min = 2
		e.target_max = 2
		return e

	## APNAP order (CR 101.4): the active player first.
	static func apnap(g: MtgGame) -> Array[int]:
		var out: Array[int] = []
		for k in g.players.size():
			out.append((g.active_player + k) % g.players.size())
		return out

	## "Sacrifice any number of <kind>" on resolution (Reprocess; Last-Ditch
	## Effort, ulg): how many, then which, asked of [param pid] through its
	## own agent (a human seat is held open on both), then every one
	## sacrificed in one event. The hint is [param hint] of the least
	## valuable first. Returns how many were sacrificed.
	static func sacrifice_any_number(g: MtgGame, pid: int, filter: Callable, what: String,
			card_name: String, hint := 0) -> int:
		var pile: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if g.is_present(i) and filter.call(i): pile.append(i)
		if pile.is_empty():
			return 0
		pile.sort_custom(P.least_worth_first)
		var count := g.agents[pid].choose_number(g, pid, 0, pile.size(),
			"%s: sacrifice how many %s?" % [card_name, what], clampi(hint, 0, pile.size()))
		var meal: Array[CardInstance] = []
		for _n in count:
			if pile.is_empty(): break
			var pick := g.agents[pid].choose_card(g, pid, pile, PlayerChoice.sacrifice_prompt(what),
				false, false, true)
			if pick == null or not pile.has(pick): pick = pile[0]
			pile.erase(pick)
			meal.append(pick)
		if meal.is_empty():
			return 0
		g.depart_together(meal, g.sacrifice_permanent)
		return meal.size()


## "Target opponent reveals their hand. You choose a <kind> card from it.
## That player discards that card." (Duress; Ostracize, ulg). The hand is
## revealed to the table; the caster must choose when a card qualifies.
## A ChosenDiscardEffect, so the fair AI reads it as an aimed discard.
class RevealedDiscard extends ChosenDiscardEffect:
	var kind: String
	var eligible: Callable
	func _init(p_kind: String, p_eligible: Callable) -> void:
		super(1)
		kind = p_kind
		eligible = p_eligible
	func candidates(g: MtgGame, who: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for i in g.players[who].hand:
			if eligible.call(i): out.append(i)
		return out
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var who := t.player_id
		var names: Array = []
		for i in g.players[who].hand: names.append(i.data.card_name)
		g.reveal_information(-1, "%s — %s's hand" % [s.data.card_name, g.players[who].player_name], names)
		var left := candidates(g, who)
		if left.is_empty():
			g.log_line("%s: no %s card to discard" % [s.data.card_name, kind])
			return
		left.sort_custom(P.costliest_card_first)
		var pick := g.agents[pid].choose_card(g, pid, left,
			"%s: choose a %s card for %s to discard" % [s.data.card_name, kind, g.players[who].player_name],
			false, false, true)
		if pick == null or not left.has(pick): pick = left[0]
		g.discard_cards(who, [pick])
	func describe() -> String:
		return "target opponent reveals their hand; you choose a %s card from it; that player discards that card" % kind


# ============================================================ white classes

## Congregate: every creature on the battlefield (both sides; a phased-out
## one does not exist, CR 702.26b), counted as it resolves.
class Congregate extends GainLifeEffect:
	func _init() -> void:
		super(2)
		target_player()
		with_ai_role(&"life_per_creature_on_battlefield", {"per": 2})
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		var n := 0
		for i in g.all_battlefield():
			if i.is_creature() and g.is_present(i): n += 1
		if n > 0: g.adjust_life(t.player_id, 2 * n)
	func describe() -> String:
		return "target player gains 2 life for each creature on the battlefield"


## Humble: base 0/1 (layer 7b, the typed half the readers see) and a
## floating "loses all abilities" bound to this creature (see the header).
class Humble extends SetBasePowerToughnessEffect:
	func _init() -> void:
		super(0, 1)
		with_ai_role(&"silence_and_shrink_until_eot", {"power": 0, "toughness": 1})
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g.continuous.add_floating_static(s, StaticAbility.removing_all_abilities(
			Humble._is_it.bind(i.id, i.layer_timestamp), "Loses all abilities until end of turn."),
			ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
		g.continuous.add_until_eot_base_pt(i.id, 0, 1)
		g.recalculate()
		g.log_line("%s loses all abilities and is a 0/1 until end of turn" % i.data.card_name)
	static func _is_it(_g: MtgGame, _s: CardInstance, inst: CardInstance, id: int, stamp: int) -> bool:
		return inst.id == id and inst.layer_timestamp == stamp
	func describe() -> String:
		return "until end of turn, target creature loses all abilities and has base power and toughness 0/1"


static func _planar_birth(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var rising: Array[CardInstance] = []
	for p in U.apnap(g):
		for card in g.players[p].graveyard:
			if P.basic_land_card(card): rising.append(card)
	if rising.is_empty(): return
	var entries: Array = []
	for card in rising:
		entries.append({"instance": card, "controller": card.owner_id, "tapped": true})
	g.put_onto_battlefield_together(entries)


## Exhume: each player's own creature card, chosen APNAP before anything
## moves (CR 101.4); the cards then enter together (E10). The hint is the
## chooser's costliest card — its own graveyard, public to everyone.
class Exhume extends EffectBase:
	func _init() -> void:
		with_ai_role(&"each_player_reanimates_one")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var entries: Array = []
		for p in U.apnap(g):
			var pile: Array[CardInstance] = []
			for card in g.players[p].graveyard:
				if card.data.is_creature(): pile.append(card)
			if pile.is_empty(): continue
			pile.sort_custom(P.costliest_card_first)
			var pick := g.agents[p].choose_card(g, p, pile,
				"Exhume: choose a creature card in your graveyard to put onto the battlefield",
				false, false, true)
			if pick == null or not pile.has(pick): pick = pile[0]
			entries.append({"instance": pick, "controller": p})
		g.put_onto_battlefield_together(entries)
	func describe() -> String:
		return "each player puts a creature card from their graveyard onto the battlefield"


## Redeem: "prevent all damage that would be dealt this turn" to each of
## its targets — the combat-prevention table's all-damage entry.
class Redeem extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("up to two target creatures")
		target_min = 0
		target_max = 2
		is_damage_prevention = true
		ai_helpful = true
		with_ai_role(&"prevent_all_damage_to_creatures")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g.continuous.add_until_eot_combat_prevention(i.id, false, false, false, false, true)
		g.recalculate()
		g.log_line("All damage that would be dealt to %s this turn will be prevented" % i.data.card_name)
	func describe() -> String:
		return "prevent all damage that would be dealt this turn to up to two target creatures"


## Waylay: three Knights, exiled at the beginning of the next cleanup step.
class Waylay extends CreateTokenEffect:
	func _init() -> void:
		super("Knight", 2, 2, Mtg.ManaColor.W, "knight", 3)
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var rows: Array = []
		for k in g.create_token(pid, token, count):
			rows.append([k.id, k.layer_timestamp])
		if rows.is_empty(): return
		g.schedule_cleanup_action(Waylay._exile_them.bind(rows), s, pid,
			"Exile the Knight tokens Waylay created.")
	static func _exile_them(g: MtgGame, rows: Array) -> void:
		var going: Array[CardInstance] = []
		for row in rows:
			var k := g.find_instance(int(row[0]))
			if k != null and k.zone == Mtg.Zone.BATTLEFIELD and k.layer_timestamp == int(row[1]):
				going.append(k)
		g.depart_together(going, g.exile_permanent)
	func describe() -> String:
		return "create three 2/2 white Knight creature tokens; exile them at the beginning of the next cleanup step"


# ============================================================= blue classes

## "Draw N cards, then discard a card" (Catalog) — Sift's shape
## (sth/_spells.gd): a DrawEffect for the AI's eyes.
class Loot extends DrawEffect:
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.draw_cards(pid, count)
		if g.players[pid].hand.is_empty(): return
		var chosen := g.agents[pid].choose_discard(g, pid, 1)
		if chosen.is_empty() or not g.players[pid].hand.has(chosen[0]):
			chosen = [g.players[pid].hand[-1]]
		g.discard_cards(pid, chosen)
	func describe() -> String:
		return "draw %d cards, then discard a card" % count


## "Target player draws X cards" (Stroke of Genius).
class DrawX extends DrawEffect:
	func _init() -> void:
		super(0)
		x_cards()
		target_player()
	func describe() -> String:
		return "target player draws X cards"


static func _curfew(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var going: Array[CardInstance] = []
	for p in U.apnap(g):
		var own: Array[CardInstance] = []
		for i in g.players[p].battlefield:
			if i.is_creature() and g.is_present(i): own.append(i)
		if own.is_empty(): continue
		# Hint: the chooser's least valuable creature (a token last — it
		# would cease to exist, CR 111.7).
		own.sort_custom(_return_first)
		var pick := g.agents[p].choose_card(g, p, own,
			"Curfew: choose a creature you control to return to its owner's hand", false, false, true)
		if pick == null or not own.has(pick): pick = own[0]
		going.append(pick)
	g.depart_together(going, g.return_to_hand)

static func _return_first(a: CardInstance, b: CardInstance) -> bool:
	if a.is_token != b.is_token: return not a.is_token
	return P.least_worth_first(a, b)


static func _hibernation(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var going: Array[CardInstance] = []
	for i in g.all_battlefield():
		if g.is_present(i) and P.green(i): going.append(i)
	g.depart_together(going, g.return_to_hand)


static func _sunder(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var going: Array[CardInstance] = []
	for i in g.all_battlefield():
		if g.is_present(i) and i.is_land(): going.append(i)
	g.depart_together(going, g.return_to_hand)


## Tolarian Winds: the number DISCARDED is the hand's size (see the header).
class TolarianWinds extends DrawEffect:
	func _init() -> void:
		super(0)
		with_ai_role(&"discard_hand_draw_that_many")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var n := g.players[pid].hand.size()
		if n <= 0: return
		g.discard_hand(pid)
		g.draw_cards(pid, n)
	func describe() -> String:
		return "discard all the cards in your hand, then draw that many cards"


## Windfall: every hand goes (APNAP), then everyone draws the largest count.
class Windfall extends EffectBase:
	func _init() -> void:
		with_ai_role(&"wheel_greatest_hand")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var most := 0
		for p in U.apnap(g):
			most = maxi(most, g.players[p].hand.size())
			if not g.players[p].hand.is_empty(): g.discard_hand(p)
		if most <= 0: return
		for p in U.apnap(g):
			g.draw_cards(p, most)
	func describe() -> String:
		return "each player discards their hand, then draws cards equal to the greatest number of cards a player discarded this way"


# ============================================================ black classes

## Corrupt: the Swamps you control as it resolves; life for what was dealt.
class Corrupt extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
		with_ai_role(&"swamp_count_drain")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var n := 0
		for i in g.players[pid].battlefield:
			if g.is_present(i) and i.is_land() and i.has_subtype("swamp"): n += 1
		if n <= 0: return
		g.deal_damage(s, t, n, false, func(dealt: int) -> void:
			if dealt > 0: g.adjust_life(pid, dealt))
	func describe() -> String:
		return "deals damage to any target equal to the number of Swamps you control; you gain life equal to the damage dealt this way"


## Ill-Gotten Gains (see the header).
class IllGottenGains extends EffectBase:
	func _init() -> void:
		with_ai_role(&"wheel_regrow_three")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		g._rec(s, &"exile_after_resolution")
		s.exile_after_resolution = true   # "Exile Ill-Gotten Gains"
		var order := U.apnap(g)
		for p in order:
			if not g.players[p].hand.is_empty(): g.discard_hand(p)
		var back := {}
		for p in order:
			var pile: Array[CardInstance] = []
			for card in g.players[p].graveyard:
				if card != s: pile.append(card)
			if pile.is_empty(): continue
			pile.sort_custom(P.costliest_card_first)
			var most := mini(3, pile.size())
			var n := g.agents[p].choose_number(g, p, 0, most,
				"Ill-Gotten Gains: return how many cards from your graveyard to your hand?", most)
			var picks: Array[CardInstance] = []
			for _k in n:
				if pile.is_empty(): break
				var pick := g.agents[p].choose_card(g, p, pile,
					"Ill-Gotten Gains: choose a card to return to your hand", false, false, true)
				if pick == null or not pile.has(pick): pick = pile[0]
				pile.erase(pick)
				picks.append(pick)
			back[p] = picks
		for p in order:
			for card in back.get(p, []):
				g.return_from_graveyard_to_hand(card)
	func describe() -> String:
		return "exile Ill-Gotten Gains; each player discards their hand, then returns up to three cards from their graveyard to their hand"


static func _rain_of_filth(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var lands: Array = []
	for i in g.players[pid].battlefield:
		if g.is_present(i) and i.is_land(): lands.append([i.id, i.layer_timestamp])
	if lands.is_empty(): return
	# One ability object for the whole grant: the live lists compare it by
	# identity across recalculations.
	var filth := ManaAbility.new(Mtg.ManaColor.B).without_tap().with_sacrifice()
	g.continuous.add_floating_static(s, StaticAbility.new(_filth.bind(lands, filth),
		"Sacrifice this land: Add {B}.").changing_abilities(), ContinuousEffects.Duration.END_OF_TURN)
	g.recalculate()

static func _filth(g: MtgGame, _s: CardInstance, lands: Array, filth: ManaAbility) -> void:
	for row in lands:
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and not i.phased_out \
				and i.layer_timestamp == int(row[1]):
			i.cur_mana_abilities.append(filth)


## Reprocess: what was sacrificed, drawn back. A DrawEffect for the AI.
class Reprocess extends DrawEffect:
	func _init() -> void:
		super(0)
		with_ai_role(&"sacrifice_any_number_draw")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		# Hint: the tokens, and the lands beyond the sixth.
		var tokens := 0
		var lands := 0
		for i in g.players[pid].battlefield:
			if not g.is_present(i): continue
			if i.is_token and P.artifact_creature_or_land(i): tokens += 1
			elif i.is_land(): lands += 1
		var eaten := U.sacrifice_any_number(g, pid, P.artifact_creature_or_land,
			"artifacts, creatures, and/or lands", "Reprocess", tokens + maxi(lands - 6, 0))
		if eaten > 0: g.draw_cards(pid, eaten)
	func describe() -> String:
		return "sacrifice any number of artifacts, creatures, and/or lands; draw a card for each permanent sacrificed this way"


## Unnerve: each opponent chooses their own two (fewer from a smaller hand).
class Unnerve extends EffectBase:
	func _init() -> void:
		with_ai_role(&"each_opponent_discards", {"count": 2})
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for p in U.apnap(g):
			if p == pid or g.players[p].has_lost: continue
			var hand: Array = g.players[p].hand
			var n := mini(2, hand.size())
			if n <= 0: continue
			var chosen: Array[CardInstance] = []
			for card in g.agents[p].choose_discard(g, p, n):
				if hand.has(card) and not chosen.has(card) and chosen.size() < n: chosen.append(card)
			for card in hand:
				if chosen.size() >= n: break
				if not chosen.has(card): chosen.append(card)
			g.discard_cards(p, chosen)
	func describe() -> String:
		return "each opponent discards two cards"


# ============================================================== red classes

## Acidic Soil: each player, the lands they control, in one event.
class AcidicSoil extends EffectBase:
	func _init() -> void:
		with_ai_role(&"damage_each_player_per_land")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var hits := {}
		for p in U.apnap(g):
			var n := 0
			for i in g.players[p].battlefield:
				if g.is_present(i) and i.is_land(): n += 1
			hits[p] = n
		g.begin_simultaneous()
		for p in U.apnap(g):
			if int(hits[p]) > 0 and not g.players[p].has_lost:
				g.deal_damage(s, TargetRef.player(p), int(hits[p]))
		g.end_simultaneous()
	func describe() -> String:
		return "deals damage to each player equal to the number of lands they control"


## Disorder: the white creatures and the players controlling one, judged
## before any damage; one event.
class Disorder extends DamageAllEffect:
	func _init() -> void:
		super(2, "each white creature", P.white_creature)
		with_ai_role(&"white_creatures_and_their_controllers", {"amount": 2})
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var victims: Array[CardInstance] = []
		var seats := {}
		for i in g.all_battlefield():
			if g.is_present(i) and P.white_creature(i):
				victims.append(i)
				seats[i.controller_id] = true
		if victims.is_empty(): return
		g.begin_simultaneous()
		for i in victims:
			g.deal_damage(s, TargetRef.card(i), amount)
		for p in U.apnap(g):
			if seats.has(p) and not g.players[p].has_lost:
				g.deal_damage(s, TargetRef.player(p), amount)
		g.end_simultaneous()
	func describe() -> String:
		return "deals 2 damage to each white creature and each player who controls a white creature"


static func _falter(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_grounded,
		"Creatures without flying can't block this turn."), ContinuousEffects.Duration.END_OF_TURN)
	g.recalculate()

static func _grounded(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and not i.has_keyword(Mtg.Keyword.FLYING):
			i.cur_cant_block_filter = _every_attacker

static func _every_attacker(_attacker: CardInstance) -> bool:
	return true


## Gamble (see the header). A SearchLibraryEffect for the AI's eyes.
class Gamble extends SearchLibraryEffect:
	func _init() -> void:
		super("a card")
		with_ai_role(&"tutor_then_random_discard")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.search_library(pid, Callable(), "Search your library for a card", false, false)
		g.discard_random(pid, 1)
		g.shuffle_library(pid)
	func describe() -> String:
		return "search your library for a card, put that card into your hand, discard a card at random, then shuffle"


## Goblin Offensive: the spell's X, as it resolves.
class XTokens extends CreateTokenEffect:
	func _init() -> void:
		super("Goblin", 1, 1, Mtg.ManaColor.R, "goblin", 0)
		with_ai_role(&"x_tokens")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, x := 0) -> void:
		if x > 0: g.create_token(pid, token, x)
	func describe() -> String:
		return "create X 1/1 red Goblin creature tokens"


## Headlong Rush: the creatures attacking as it resolves.
class HeadlongRush extends MassPumpEffect:
	func _init() -> void:
		super(0, 0, "attacking creatures", [Mtg.Keyword.FIRST_STRIKE])
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		for id in g.combat.attackers.keys():
			var i := g.find_instance(int(id))
			if g.is_present(i) and i.is_creature():
				g.continuous.add_until_eot_pump(i.id, 0, 0, granted_keywords)
		g.log_line("%s: attacking creatures gain first strike until end of turn" % s.data.card_name)
		g.recalculate()


## Meltdown: each artifact whose printed mana value is X or less, in one
## departure. The static filter (every artifact) is only the readers'
## approximation; the resolution reads X.
class Meltdown extends DestroyAllEffect:
	func _init() -> void:
		super("each artifact with mana value X or less", P.artifact)
		with_ai_role(&"artifact_sweep_mana_value_x")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, x := 0) -> void:
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if g.is_present(i) and P.artifact(i) and i.data.cost.mana_value() <= x:
				victims.append(i)
		g.depart_together(victims, func(i: CardInstance) -> void: g.destroy(i))
	func describe() -> String:
		return "destroy each artifact with mana value X or less"


# ============================================================ green classes

## Gaea's Bounty: up to two revealed Forest cards, then one shuffle. A
## declined first search ends it.
class GaeasBounty extends SearchLibraryEffect:
	const PROMPTS := ["Search your library for up to two Forest cards",
		"Search your library for up to one more Forest card"]
	func _init() -> void:
		super("up to two Forest cards", P.forest_card)
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for k in 2:
			var before := g.players[pid].hand.size()
			g.search_library(pid, filter, String(PROMPTS[k]), false, false,
				"%s — revealed card" % s.data.card_name)
			if g.players[pid].hand.size() == before: break
		g.shuffle_library(pid)
	func describe() -> String:
		return "search your library for up to two Forest cards, reveal those cards, put them into your hand, then shuffle"


static func _titanias_boon(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var own: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_creature() and g.is_present(i): own.append(i)
	for i in own:
		if g.is_present(i): g.add_counters(i, "+1/+1", 1)
