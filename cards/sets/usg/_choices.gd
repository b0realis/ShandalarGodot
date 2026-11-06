extends RefCounted
## Urza's Saga (_choices, Pack 10). Choices made as a spell resolves:
## Catastrophe's "lands or creatures", Persecute's color, Victimize's
## sacrifice.
##
## Every choice is made on resolution (CR 608.2d) and asked of the seat the
## card names through its DecisionAgent funnel, so the pre-flight holds a
## human seat; each hint is computed from what that seat may know
## (docs/fair-play.md) — the public board and its own hand, never the other
## hand.
##
## - Catastrophe: a choice on resolution, not a mode — a mode would be
##   announced as it is cast (CR 700.2a), which Catastrophe does not do. One
##   departure either way (Wrath of God's bracket); "Creatures destroyed this
##   way can't be regenerated" reaches a land that is also a creature when
##   the lands go. Hint: the side of the table whose loss costs the other
##   seat more, read off the public board (Extinction's worth,
##   cards/sets/tmp/_choices.gd).
## - Persecute: the color, then the reveal to both seats, then every card of
##   that color discarded at once (printed colors in a hand, CR 105.2; a
##   land is colorless). Hint: the color the target shows most on the table
##   and in its graveyard (its permanents, its basic land types, its used
##   cards); against its caster, the color the caster holds least of.
## - Victimize: two target creature cards in your graveyard (two different
##   cards, CR 601.2c), chosen as it is cast; on resolution a creature is
##   sacrificed (its controller picks, weakest first), and only if one was
##   ("If you do") do the targets still in the graveyard return, tapped, under
##   the caster's control. A creature sacrificed now is a new card in the
##   graveyard, never one of the targets. The two cards enter at ONE moment
##   (MtgGame.put_onto_battlefield_together, Pack 10 E10), so a returned
##   "whenever another creature enters" ability sees the other.
## tests/cards/test_pack_10_B2_choices.gd pins each card.


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Catastrophe": c.spell(Catastrophe.new())
		"Persecute": c.spell(Persecute.new())
		"Victimize": c.spell(Victimize.new())
		_: return false
	return true


# ============================================================== Catastrophe

class Catastrophe extends DestroyAllEffect:
	const OPTIONS: Array[String] = ["Destroy all lands", "Destroy all creatures"]
	func _init() -> void:
		super("all lands or all creatures", Callable(), false)
		with_ai_role(&"sweep_lands_or_creatures")
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var pick := g.agents[pid].choose_option(g, pid, OPTIONS,
			"Catastrophe: destroy all lands or all creatures?", Catastrophe.hint(g, pid))
		var lands := pick == 0
		g.log_line("%s chooses to destroy all %s (%s)" % [g.players[pid].player_name,
			"lands" if lands else "creatures", s.data.card_name])
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if g.is_present(i) and (i.is_land() if lands else i.is_creature()):
				victims.append(i)
		# "Creatures destroyed this way can't be regenerated" — judged on
		# each victim as the board stood before any of them left.
		g.depart_together(victims, func(i: CardInstance) -> void: g.destroy(i, not i.is_creature()))
	## 0 for the lands, 1 for the creatures: whichever side's loss costs
	## the other seat more. Lands weigh three each.
	static func hint(g: MtgGame, pid: int) -> int:
		var creatures := 0
		var lands := 0
		for i in g.all_battlefield():
			if not g.is_present(i):
				continue
			var side := 1 if i.controller_id != pid else -1
			if i.is_creature(): creatures += side * (1 + i.data.cost.mana_value() \
				+ maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0))
			if i.is_land(): lands += side * 3
		return 1 if creatures >= lands else 0
	func describe() -> String:
		return "destroy all lands or all creatures (your choice as it resolves); creatures destroyed this way can't be regenerated"


# ================================================================ Persecute

class Persecute extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
		with_ai_role(&"discard")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var hint := Persecute.hint(g, pid, who)
		var color := Persecute.one_color(g.agents[pid].choose_color(g, pid,
			"Persecute: choose a color", hint), hint)
		var hand: Array = []
		for card in g.players[who].hand: hand.append(card.data.card_name)
		g.log_line("%s chooses %s (%s)" % [g.players[pid].player_name, String(Mtg.COLOR_NAMES[color]).to_lower(),
			s.data.card_name])
		g.reveal_information(-1, "%s — %s's hand" % [s.data.card_name, g.players[who].player_name], hand)
		g.log_line("%s reveals their hand: %s" % [g.players[who].player_name,
			", ".join(PackedStringArray(hand)) if not hand.is_empty() else "no cards"])
		var doomed: Array[CardInstance] = []
		for card in g.players[who].hand:
			if (card.data.color_mask() & color) != 0: doomed.append(card)
		if not doomed.is_empty():
			g.discard_cards(who, doomed)
	## One color out of an answer: its first WUBRG bit, [param fallback]
	## when it names none.
	static func one_color(answer: int, fallback: int) -> int:
		for color in Mtg.WUBRG:
			if (answer & int(color)) != 0: return int(color)
		return fallback
	## See the module header. Public facts only.
	static func hint(g: MtgGame, pid: int, who: int) -> int:
		var score := {}
		for color in Mtg.WUBRG: score[int(color)] = 0
		if who == pid:
			# Against its own caster: the color it holds least of (its own hand).
			for card in g.players[pid].hand:
				for color in Mtg.WUBRG:
					if (card.data.color_mask() & int(color)) != 0: score[int(color)] -= 1
		else:
			for i in g.players[who].battlefield:
				if i.face_down or i.phased_out: continue
				for color in Mtg.WUBRG:
					if (i.cur_colors & int(color)) != 0: score[int(color)] += 2
				for kind in Mtg.BASIC_LAND_COLORS:
					if i.is_land() and i.has_subtype(kind): score[int(Mtg.BASIC_LAND_COLORS[kind])] += 1
			for card in g.players[who].graveyard:
				for color in Mtg.WUBRG:
					if (card.data.color_mask() & int(color)) != 0: score[int(color)] += 1
		var best := int(Mtg.WUBRG[0])
		for color in Mtg.WUBRG:
			if int(score[int(color)]) > int(score[best]): best = int(color)
		return best
	func describe() -> String:
		return "target player reveals their hand and discards all cards of the color of your choice"


# ================================================================ Victimize

class Victimize extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
			"two target creature cards in your graveyard")
		target_min = 2
		target_max = 2
		to_battlefield()
		with_ai_role(&"needs_own_permanent", {"filter": Victimize.creature})
	static func creature(i: CardInstance) -> bool:
		return i.is_creature()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		resolve_multi(g, s, pid, [] if t == null else [t], x)
	func resolve_multi(g: MtgGame, s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		var bodies: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if g.is_present(i) and i.is_creature(): bodies.append(i)
		if bodies.is_empty():
			g.log_line("%s has no creature to sacrifice (%s)" % [g.players[pid].player_name, s.data.card_name])
			return
		bodies.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var wa := Victimize._worth_of(a)
			var wb := Victimize._worth_of(b)
			if wa != wb: return wa < wb
			return a.id < b.id)
		var victim := g.agents[pid].choose_card(g, pid, bodies,
			"Victimize: sacrifice a creature", false, false, true)
		if victim == null or not bodies.has(victim): victim = bodies[0]
		var stamp := victim.layer_timestamp
		g.sacrifice_permanent(victim)
		if victim.zone == Mtg.Zone.BATTLEFIELD and victim.layer_timestamp == stamp:
			return   # nothing was sacrificed: "if you do" fails
		var cards: Array[CardInstance] = []
		for t in targets:
			var card := g.find_instance((t as TargetRef).instance_id)
			if card != null and card.zone == Mtg.Zone.GRAVEYARD: cards.append(card)
		# Together (E10): both on the battlefield before either is announced.
		var entries: Array = []
		for card in cards:
			entries.append({"instance": card, "controller": pid, "tapped": true})
		g.put_onto_battlefield_together(entries)
	static func _worth_of(i: CardInstance) -> int:
		return 1 + i.data.cost.mana_value() + maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0)
	func describe() -> String:
		return "choose two target creature cards in your graveyard; sacrifice a creature; if you do, return the chosen cards to the battlefield tapped"
