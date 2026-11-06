extends RefCounted
## Urza's Destiny (_spells, Pack 10). Instants and sorceries: one-shot
## spell effects, their targets, and the same-name exile family.
##
## Effects are TYPED wherever the engine has the shape — the fair AI reads
## them (engine/ai/effect_intent.gd) — and a card-local class subclasses the
## typed effect it most resembles (Wake of Destruction a DestroyEffect,
## Multani's Decree a DestroyAllEffect that pays out, Trumpet Blast a
## MassPumpEffect over the attackers, Encroach a ChosenDiscardEffect). A
## card-local effect the reader cannot price declares its shape through
## [member EffectBase.ai_role] for the Stage 4 policy. Targeting
## restrictions live in the TargetSpec, never in resolve().
##
## - THE SAME-NAME EXILE (Scour, Quash, Eradicate, Sowing Salt, Splinter —
##   Lobotomy's search, cards/sets/tmp/_choices.gd, copied here as
##   [class SameName] with its card's own words): the target goes first
##   (exiled, or countered for Quash — a spell that can't be countered stays
##   where it is and the search still happens), then every card with its
##   name that its controller (as it last was, CR 608.2h) owns: every copy
##   in the graveyard, which is public; in the hand and the library the
##   searcher may fail to find (CR 701.19b), so it is asked HOW MANY of the
##   copies there it exiles, the hand first — copies of one name are
##   interchangeable, so a count is the whole answer — and it looks at the
##   hand it searches (shown to the searcher alone). Then that player
##   shuffles, found or not.
## - Flicker: the permanent returns as a new object (CR 400.7) under its
##   OWNER's control. An Aura is not cast as it returns, so its owner
##   chooses something it could enchant (CR 303.4f — Eureka's census,
##   leg/eureka.gd); with nothing to enchant it stays in exile (303.4g).
## - Donate's two slots: the player, then the permanent you control; the
##   permanent's effect re-judges the player slot (CR 608.2b), Legerdemain's
##   shape (cards/sets/tmp/_spells.gd). The control change lasts
##   indefinitely (MtgGame.change_control).
## - Fatigue: one skipped draw step, counted on the player and spent by the
##   next draw step it reaches (Ivory Gargoyle's counter, all/_triggers.gd).
## - Bubbling Muck: High Tide's delayed mana trigger (fem/_rules.gd) for
##   Swamps and {B}, every player's, until end of turn.
## - Encroach: the hand is revealed to both seats, then the caster picks a
##   nonbasic land card from it (basic: the printed supertype); "target
##   player" — the caster may aim it at themselves.
## - Landslide: "any number of Mountains" is how many, then which (Mind
##   Maggots' shape, exo/_triggers.gd), asked as it resolves; the Mountains
##   (live subtype, CR 305.7) go in one event and the damage is the number
##   that actually left. The hint: just enough for lethal, else keep three.
## - Wake of Destruction: the target and every other land with its name,
##   destroyed in one event (depart_together, Wrath of God's bracket).
## - Multani's Decree: 2 life for each enchantment DESTROYED — each one
##   that left the battlefield (a regenerated or indestructible one did not;
##   one Forbidden Crypt exiles instead still was).
## - Plow Under: one effect, two lands (two different objects, CR 601.2c).
##   Two of one owner's lands go on top together and that owner orders them
##   (CR 401.4), asked of the owner; the answer goes on top.
## tests/cards/test_pack_10_B2_spells.gd and test_pack_10_B2_same_name.gd
## pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const EUREKA := preload("res://cards/sets/leg/eureka.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Flicker": c.spell(Flicker.new())
		"Scour":
			c.spell(SameNameExile.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
				P.enchantment)))
		"Solidarity": c.spell(MassPumpEffect.new(0, 5, "creatures you control").yours_only())
		# ------------------------------------------------------------- blue
		"Donate":
			var player := DonateSlot.new()
			c.spell(player).spell(Donation.new(player.target_spec))
		"Fatigue":
			c.spell(F.Action.new(_fatigue, "target player skips their next draw step",
				TargetSpec.player()).with_ai_role(&"skip_draw_step"))
		"Quash": c.spell(Quash.new())
		"Rescue":
			c.spell(ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target permanent you control").with_source_filter(P.yours) \
				.because(TargetSpec.WHY["controller"])).helpful())
		# ------------------------------------------------------------ black
		"Bubbling Muck":
			c.spell(F.Action.new(_bubbling_muck,
				"until end of turn, whenever a player taps a Swamp for mana, that player adds an additional {B}") \
				.with_ai_role(&"mana_bonus_this_turn", {"subtype": "swamp", "color": Mtg.ManaColor.B}))
		"Encroach": c.spell(Encroach.new())
		"Eradicate":
			c.spell(SameNameExile.new(TargetSpec.creature("target nonblack creature", P.nonblack) \
				.because(TargetSpec.WHY["color"])))
		"Soul Feast": c.spell(GainLifeEffect.new(-4).target_player()).spell(GainLifeEffect.new(4))
		# -------------------------------------------------------------- red
		"Landslide": c.spell(Landslide.new())
		"Reckless Abandon":
			c.with_additional_sacrifice("creature", P.creature)
			c.spell(DamageEffect.new(4).any_target())
		"Sowing Salt":
			c.spell(SameNameExile.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonbasic land",
				P.nonbasic_land).because(TargetSpec.WHY["basic_land"])))
		"Trumpet Blast": c.spell(AttackersPump.new())
		"Wake of Destruction": c.spell(WakeOfDestruction.new())
		# ------------------------------------------------------------ green
		"Magnify": c.spell(MassPumpEffect.new(1, 1))
		"Multani's Decree": c.spell(MultanisDecree.new())
		"Plow Under": c.spell(PlowUnder.new())
		"Splinter":
			c.spell(SameNameExile.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact",
				P.artifact)))
		_: return false
	return true


# ================================================================ predicates

## Instance tests read LIVE characteristics (cur_*), never printed data.
class P:
	static func creature(i: CardInstance) -> bool: return i.is_creature()
	static func land(i: CardInstance) -> bool: return i.is_land()
	static func artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	static func enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
	static func nonblack(i: CardInstance) -> bool: return not i.has_color(Mtg.ManaColor.B)
	static func nontoken(i: CardInstance) -> bool: return not i.is_token
	static func nonbasic_land(i: CardInstance) -> bool:
		return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0
	static func mountain(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("mountain")
	static func instant_or_sorcery(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.INSTANT) or i.is_type(Mtg.CardType.SORCERY)
	## "You control": the seat the spell acts for (MtgGame.controller_acting_for).
	static func yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return i.controller_id == g.controller_acting_for(s)


## Helpers shared by the module's functions and its inner classes (an
## inner class reaches a sibling class by name).
class U:
	static func who(g: MtgGame, pid: int) -> String:
		return g.players[pid].player_name

	static func names(cards: Array) -> Array:
		var out: Array = []
		for card in cards: out.append(card.data.card_name)
		return out


# =========================================================== same-name exile

## "Search its controller's graveyard, hand, and library for all cards with
## the same name as that <object> and exile them. Then that player
## shuffles." See the module header.
class SameName:
	static func search(g: MtgGame, s: CardInstance, pid: int, victim: int, named: String) -> void:
		var label := s.data.card_name
		var p := g.players[victim]
		g.log_line("%s searches %s's graveyard, hand, and library for %s (%s)" % [
			U.who(g, pid), U.who(g, victim), named, label])
		for card in p.graveyard.duplicate():
			if card.data.card_name == named: g.exile_from_graveyard(card)
		var in_hand: Array[CardInstance] = []
		for card in p.hand:
			if card.data.card_name == named: in_hand.append(card)
		var in_library: Array[CardInstance] = []
		for card in p.library:
			if card.data.card_name == named: in_library.append(card)
		if victim != pid and not p.hand.is_empty():
			var seen := U.names(p.hand)
			seen.sort()
			g.reveal_information(pid, "%s — %s's hand (searched)" % [label, U.who(g, victim)], seen)
		# Hint: every copy the other player owns; none of the searcher's own.
		var take := victim != pid
		for card in SameName._found(g, pid, in_hand, take,
				"%s: exile how many of the %d card(s) named %s in %s's hand?" % [
					label, in_hand.size(), named, U.who(g, victim)]):
			g.exile_from_hand(card)
		for card in SameName._found(g, pid, in_library, take,
				"%s: exile how many of the %d card(s) named %s in %s's library?" % [
					label, in_library.size(), named, U.who(g, victim)]):
			g.exile_library_card(card)
		g.shuffle_library(victim)

	## The copies the searcher finds in one hidden zone: a count (0 = fail
	## to find), nothing asked when there is none.
	static func _found(g: MtgGame, pid: int, copies: Array[CardInstance], take: bool,
			prompt: String) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		if copies.is_empty():
			return out
		var n := g.agents[pid].choose_number(g, pid, 0, copies.size(), prompt,
			copies.size() if take else 0)
		for k in clampi(n, 0, copies.size()):
			out.append(copies[k])
		return out


## Scour, Eradicate, Sowing Salt, Splinter: exile the target, then the
## search — its name and controller read before it goes.
class SameNameExile extends ExileEffect:
	func _init(spec: TargetSpec) -> void:
		super(spec)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		var victim := i.controller_id
		var named := i.data.card_name
		g.exile_permanent(i)
		SameName.search(g, s, pid, victim, named)
	func describe() -> String:
		return "exile %s; then exile every card with its name from its controller's graveyard, hand, and library, and that player shuffles" \
			% target_spec.description


## Quash: counter the spell (its controller as it was on the stack), then
## the search — the countered card is in the graveyard by then and goes too.
class Quash extends CounterEffect:
	func _init() -> void:
		super("target instant or sorcery spell", P.instant_or_sorcery)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		if spell == null:
			return
		var item := g.find_stack_item(spell)
		var victim := spell.controller_id if item == null else item.controller
		var named := spell.data.card_name
		g.counter_spell(spell)
		SameName.search(g, s, pid, victim, named)
	func describe() -> String:
		return "counter target instant or sorcery spell; then exile every card with its name from its controller's graveyard, hand, and library, and that player shuffles"


# ============================================================ white classes

## Flicker: see the module header.
class Flicker extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nontoken permanent", P.nontoken)
		with_ai_role(&"flicker_permanent")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i) or i.is_token:
			return
		g.exile_permanent(i)
		if i.zone != Mtg.Zone.EXILE:
			return   # it went elsewhere: there is nothing to return
		var owner := i.owner_id
		if not i.data.is_aura():
			g.return_from_exile_to_play(i, owner)
			return
		var hosts: Array[CardInstance] = EUREKA.EurekaEffect._hosts(g, i)
		if hosts.is_empty():
			g.log_line("%s has nothing to enchant and stays in exile" % i.data.card_name)
			return
		var friendly := EffectIntent.aura_aim(i.data) != EffectIntent.Aim.HOSTILE
		hosts.sort_custom(EUREKA.EurekaEffect._host_order.bind(owner, friendly))
		var host := g.agents[owner].choose_card(g, owner, hosts,
			"Flicker: choose what %s enchants" % i.data.card_name, false, false, true)
		if host == null or not hosts.has(host):
			host = hosts[0]
		g.attach_aura_from_anywhere(i, host, owner)
	func describe() -> String:
		return "exile target nontoken permanent, then return it to the battlefield under its owner's control"


# ============================================================= blue classes

## Donate, slot 1: the player. It does nothing itself; Donation hands over.
class DonateSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
		with_ai_role(&"donate_permanent")
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "the player who gains control"


## Donate, slot 2 and the hand-over.
class Donation extends EffectBase:
	var player_spec: TargetSpec
	func _init(first: TargetSpec) -> void:
		player_spec = first
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent you control") \
			.with_source_filter(P.yours).because(TargetSpec.WHY["controller"])
		with_ai_role(&"donate_permanent")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var refs := g.current_targets()
		if refs.is_empty() or refs[0] == null or not (refs[0] as TargetRef).is_player or t == null:
			return
		if not player_spec.is_legal(g, refs[0], s, [], pid):
			return   # the player is no longer a legal target (CR 608.2b)
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		g.change_control(i, (refs[0] as TargetRef).player_id)
	func describe() -> String:
		return "target player gains control of target permanent you control"


static func _fatigue(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	g._rec(g.players[who], &"skip_draw_steps")
	g.players[who].skip_draw_steps += 1
	g.log_line("%s will skip their next draw step" % U.who(g, who))


# ============================================================ black classes

## High Tide's shape (fem/_rules.gd _high_tide) for Swamps and {B}.
static func _bubbling_muck(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA,
		func(game: MtgGame, _s: CardInstance, event: GameEvent) -> void:
			var who: int = event.data.player
			game.players[who].mana_pool.add(Mtg.ManaColor.B, 1),
		"Whenever a player taps a Swamp for mana, that player adds an additional {B}.",
		func(_game: MtgGame, _s: CardInstance, event: GameEvent) -> bool:
			return event.data.instance.cur_subtypes.has("swamp")).as_mana_trigger()
	trigger.mana_bonus_subtype = "swamp"
	trigger.mana_bonus_color = Mtg.ManaColor.B
	trigger.mana_bonus_amount = 1
	var delayed := g.schedule_delayed_trigger(trigger, source.controller_id, source, true)
	delayed["expires_turn"] = g.turn_number


## Encroach: see the module header. The hint is the most valuable card for
## an opponent, the least for the caster's own hand.
class Encroach extends ChosenDiscardEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.player()
	func candidates(g: MtgGame, who: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for card in g.players[who].hand:
			if card.data.is_land() and (card.data.supertypes & Mtg.Supertype.BASIC) == 0:
				out.append(card)
		return out
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var hand := U.names(g.players[who].hand)
		g.reveal_information(-1, "%s — %s's hand" % [s.data.card_name, U.who(g, who)], hand)
		g.log_line("%s reveals their hand: %s" % [U.who(g, who),
			", ".join(PackedStringArray(hand)) if not hand.is_empty() else "no cards"])
		var choices := candidates(g, who)
		if choices.is_empty():
			return
		choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var va := a.data.cost.mana_value() + a.data.activated_abilities.size()
			var vb := b.data.cost.mana_value() + b.data.activated_abilities.size()
			if va != vb: return va > vb
			return a.id < b.id)
		if who == pid: choices.reverse()
		var pick := g.agents[pid].choose_card(g, pid, choices,
			"Encroach: choose a nonbasic land card for %s to discard" % U.who(g, who), false, false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		g.discard_cards(who, [pick])
	func describe() -> String:
		return "target player reveals their hand; you choose a nonbasic land card from it; that player discards that card"


# ============================================================== red classes

## Landslide: see the module header.
class Landslide extends DamageEffect:
	func _init() -> void:
		super(0)
		target_player(Callable(), "target player or planeswalker")
		with_ai_role(&"needs_own_permanent", {"filter": P.mountain})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var mountains: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if g.is_present(i) and P.mountain(i): mountains.append(i)
		if mountains.is_empty():
			return
		# The tapped ones first: their mana is already spent.
		mountains.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.tapped != b.tapped: return a.tapped
			return a.id < b.id)
		var hint := 0
		if t != null and t.is_player and t.player_id != pid:
			var life := g.players[t.player_id].life
			hint = life if life <= mountains.size() else maxi(0, mountains.size() - 3)
		var n := clampi(g.agents[pid].choose_number(g, pid, 0, mountains.size(),
			"Landslide: sacrifice how many Mountains? (1 damage each)", hint), 0, mountains.size())
		var picked: Array[CardInstance] = []
		if n == mountains.size():
			picked = mountains
		else:
			var rest := mountains.duplicate()
			for k in n:
				var pick := g.agents[pid].choose_card(g, pid, rest,
					"Landslide: sacrifice a Mountain (%d of %d)" % [k + 1, n], false, false, true)
				if pick == null or not rest.has(pick): pick = rest[0]
				picked.append(pick)
				rest.erase(pick)
		if picked.is_empty():
			return
		g.depart_together(picked, g.sacrifice_permanent)
		var gone := 0
		for m in picked:
			if m.zone != Mtg.Zone.BATTLEFIELD: gone += 1
		if gone > 0 and t != null:
			g.deal_damage(s, t, gone)
	func describe() -> String:
		return "sacrifice any number of Mountains; deals that much damage to target player or planeswalker"


## "Attacking creatures get +2/+0" — every attacking creature on either
## side, fixed as it resolves (Visions' AttackersPump, vis/_spells.gd).
class AttackersPump extends MassPumpEffect:
	func _init() -> void:
		super(2, 0, "attacking creatures")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		for i in g.all_battlefield():
			if i.is_creature() and g.is_present(i) and g.combat.attackers.has(i.id):
				g.continuous.add_until_eot_pump(i.id, power, toughness, granted_keywords)
		g.log_line("%s: attacking creatures get +2/+0 until end of turn" % s.data.card_name)
		g.recalculate()


## Wake of Destruction: see the module header.
class WakeOfDestruction extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", P.land))
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i):
			return
		var named := i.data.card_name
		var victims: Array[CardInstance] = [i]
		for other in g.all_battlefield():
			if other != i and g.is_present(other) and other.is_land() and other.data.card_name == named:
				victims.append(other)
		g.depart_together(victims, func(v: CardInstance) -> void: g.destroy(v))
	func describe() -> String:
		return "destroy target land and all other lands with the same name as that land"


# ============================================================ green classes

## Multani's Decree: see the module header.
class MultanisDecree extends DestroyAllEffect:
	func _init() -> void:
		super("all enchantments", P.enchantment)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var victims: Array[CardInstance] = []
		var stamps := {}
		for i in g.all_battlefield():
			if g.is_present(i) and P.enchantment(i):
				victims.append(i)
				stamps[i.id] = i.layer_timestamp
		g.depart_together(victims, func(v: CardInstance) -> void: g.destroy(v))
		var destroyed := 0
		for v in victims:
			if not (v.zone == Mtg.Zone.BATTLEFIELD and v.layer_timestamp == int(stamps[v.id])):
				destroyed += 1
		if destroyed > 0:
			g.adjust_life(pid, 2 * destroyed)
	func describe() -> String:
		return "destroy all enchantments; you gain 2 life for each enchantment destroyed this way"


## Plow Under: see the module header.
class PlowUnder extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "two target lands", P.land)
		target_min = 2
		target_max = 2
		with_ai_role(&"lands_to_library_top")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		resolve_multi(g, s, pid, [] if t == null else [t], x)
	func resolve_multi(g: MtgGame, _s: CardInstance, _pid: int, targets: Array, _x := 0) -> void:
		var lands: Array[CardInstance] = []
		for t in targets:
			var i := g.find_instance((t as TargetRef).instance_id)
			if g.is_present(i): lands.append(i)
		if lands.is_empty():
			return
		var order: Array[CardInstance] = []
		if lands.size() == 2 and lands[0].owner_id == lands[1].owner_id:
			var owner := lands[0].owner_id
			# The owner's sensible answer: the land worth more to draw again
			# on top — a nonbasic one, else the first named.
			var offered: Array[CardInstance] = lands.duplicate()
			offered.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				var na := (a.cur_supertypes & Mtg.Supertype.BASIC) == 0
				var nb := (b.cur_supertypes & Mtg.Supertype.BASIC) == 0
				if na != nb: return na
				return a.id < b.id)
			var top := g.agents[owner].choose_card_in_order(g, owner, offered,
				"Plow Under: choose the land to put on top of your library (the other goes under it)")
			if top == null or not offered.has(top): top = offered[0]
			order.append(offered[1] if top == offered[0] else offered[0])
			order.append(top)
		else:
			order.assign(lands)
		# The last one moved ends on top.
		g.depart_together(order, g.return_permanent_to_library_top)
	func describe() -> String:
		return "put two target lands on top of their owners' libraries"
