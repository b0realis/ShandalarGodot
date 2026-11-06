extends RefCounted
## Urza's Destiny (_choices, Pack 10). Choices on resolution: "reveal any
## number of <color> cards in your hand" — the five Seers, the five Scents
## and Rofellos's Gift.
##
## THE REVEAL ([class Reveal]): how many, then which — Mind Maggots' shape
## (exo/_triggers.gd) — asked of the revealing seat through its own
## DecisionAgent funnel, so the pre-flight holds a human seat on the number
## and on each card (CR 608.2d: the choice is made as the spell or ability
## resolves). Only the seat's own hand cards of the named color are
## offered (a card's color in a hand is its printed one, CR 105.2); the
## spell itself is on the stack and cannot reveal itself. Revealing all of
## them asks no "which", and a hand with none asks nothing. The revealed
## names go to BOTH seats (MtgGame.reveal_information(-1 …), CR 701.20a)
## once the reveal happens — never while a question is still open — and to
## the log. Revealing zero is legal.
##
## Each hint reads only the seat's own hand and the public board (rule 8,
## docs/fair-play.md): reveal every card of the color when the effect works
## FOR the seat (its life, its creature, an opposing target), none when it
## would work against it (its own spell, creature or face), and for
## Rofellos's Gift no more than its graveyard can pay out.
##
## - The Seers: "{2}{C}, {T}:" activated abilities; the target (a spell, a
##   creature, any target) is chosen as the ability is activated, the
##   reveal happens as it resolves. Cinder Seer is the source of its damage
##   (last known information if it has left, CR 608.2h).
## - Brine Seer / Scent of Brine: "counter target spell unless its
##   controller pays {1} for each card revealed" — the controller as it is
##   on the stack, asked through EffectBase.unless_paid; revealing nothing
##   is an "unless pays {0}" that counters nothing.
## - Nightshade and Ivy: -X/-X or +X/+X until end of turn (layer 7c), fixed
##   as it resolves.
## - Rofellos's Gift: untargeted — one enchantment card from the graveyard
##   to the hand per card revealed, as many as there are, chosen one at a
##   time.
##
## The effects are typed where the reader has a shape (Scent of Jasmine a
## GainLifeEffect, the Cinder pair DamageEffects, the Ivy pair a
## PumpEffect) with no fixed amount, so the fair AI never prices a reveal
## it has not made, and each carries the role `reveal_from_hand` with its
## color and its payout for the Stage 4 policy.
## tests/cards/test_pack_10_B2_reveals.gd pins each card.


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Jasmine Seer":
			c.activated(ActivatedAbility.new("{2}{W}", true, [RevealLife.new()],
				"{2}{W}, {T}: Reveal any number of white cards in your hand. You gain 2 life for each card revealed this way."))
		"Scent of Jasmine": c.spell(RevealLife.new())
		"Brine Seer":
			c.activated(ActivatedAbility.new("{2}{U}", true, [RevealTax.new()],
				"{2}{U}, {T}: Reveal any number of blue cards in your hand. Counter target spell unless its controller pays {1} for each card revealed this way."))
		"Scent of Brine": c.spell(RevealTax.new())
		"Nightshade Seer":
			c.activated(ActivatedAbility.new("{2}{B}", true, [RevealShrink.new()],
				"{2}{B}, {T}: Reveal any number of black cards in your hand. Target creature gets -X/-X until end of turn, where X is the number of cards revealed this way."))
		"Scent of Nightshade": c.spell(RevealShrink.new())
		"Cinder Seer":
			c.activated(ActivatedAbility.new("{2}{R}", true, [RevealBurn.new()],
				"{2}{R}, {T}: Reveal any number of red cards in your hand. This creature deals X damage to any target, where X is the number of cards revealed this way."))
		"Scent of Cinder": c.spell(RevealBurn.new())
		"Ivy Seer":
			c.activated(ActivatedAbility.new("{2}{G}", true, [RevealPump.new()],
				"{2}{G}, {T}: Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way."))
		"Scent of Ivy": c.spell(RevealPump.new())
		"Rofellos's Gift": c.spell(RevealRaise.new())
		_: return false
	return true


# ================================================================ the reveal

## "Reveal any number of <color> cards in your hand" for seat [param pid],
## [param source] asking. Returns how many were revealed. See the module
## header.
class Reveal:
	const WORDS := {Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue",
		Mtg.ManaColor.B: "black", Mtg.ManaColor.R: "red", Mtg.ManaColor.G: "green"}

	## The seat's hand cards of [param color], in hand order.
	static func cards(g: MtgGame, source: CardInstance, pid: int, color: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for card in g.players[pid].hand:
			if card != source and (card.data.color_mask() & color) != 0:
				out.append(card)
		return out

	static func ask(g: MtgGame, source: CardInstance, pid: int, color: int, hint: int) -> int:
		var shown := Reveal.cards(g, source, pid, color)
		if shown.is_empty():
			return 0
		var label := source.data.card_name
		var word: String = WORDS.get(color, "")
		var who := g.players[pid].player_name
		var n := clampi(g.agents[pid].choose_number(g, pid, 0, shown.size(),
			"%s: reveal how many %s cards from your hand?" % [label, word],
			clampi(hint, 0, shown.size())), 0, shown.size())
		if n == 0:
			g.log_line("%s reveals no %s cards (%s)" % [who, word, label])
			return 0
		var revealed: Array[CardInstance] = []
		if n == shown.size():
			revealed = shown
		else:
			var rest := shown.duplicate()
			for k in n:
				var pick := g.agents[pid].choose_card(g, pid, rest,
					"%s: reveal a %s card (%d of %d)" % [label, word, k + 1, n], false, false, true)
				if pick == null or not rest.has(pick): pick = rest[0]
				revealed.append(pick)
				rest.erase(pick)
		var names: Array = []
		for card in revealed: names.append(card.data.card_name)
		g.reveal_information(-1, "%s — %s reveals" % [label, who], names)
		g.log_line("%s reveals %s (%s)" % [who, ", ".join(PackedStringArray(names)), label])
		return revealed.size()

	## Every card of the color when the payout works for [param pid].
	static func all_or_none(g: MtgGame, source: CardInstance, pid: int, color: int,
			helps: bool) -> int:
		return Reveal.cards(g, source, pid, color).size() if helps else 0

	## Does [param t] — a creature or a player — belong to [param pid]?
	static func ours(g: MtgGame, pid: int, t: TargetRef) -> bool:
		if t == null:
			return false
		if t.is_player:
			return t.player_id == pid
		var i := g.find_instance(t.instance_id)
		return i != null and i.controller_id == pid


# ============================================================== the payouts

## Jasmine: "You gain 2 life for each card revealed this way."
class RevealLife extends GainLifeEffect:
	func _init() -> void:
		super(0)
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.W, "per_card": &"life", "amount": 2})
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.W,
			Reveal.all_or_none(g, s, pid, Mtg.ManaColor.W, true))
		if n > 0:
			g.adjust_life(pid, 2 * n)
	func describe() -> String:
		return "reveal any number of white cards in your hand; you gain 2 life for each card revealed this way"


## Brine: "Counter target spell unless its controller pays {1} for each
## card revealed this way."
class RevealTax extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell()
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.U, "per_card": &"counter_tax", "amount": 1})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		var item := g.find_stack_item(spell)
		var payer := spell.controller_id if item == null else item.controller
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.U,
			Reveal.all_or_none(g, s, pid, Mtg.ManaColor.U, payer != pid))
		if n <= 0:
			return   # "unless its controller pays {0}": nothing to refuse
		var price := "{%d}" % n
		if EffectBase.unless_paid(g, payer, ManaCost.parse(price),
				"Pay %s so that %s does not counter %s?" % [price, s.data.card_name, spell.data.card_name]):
			return
		g.counter_spell(spell)
	func describe() -> String:
		return "reveal any number of blue cards in your hand; counter target spell unless its controller pays {1} for each card revealed this way"


## Nightshade: "Target creature gets -X/-X until end of turn."
class RevealShrink extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.B, "per_card": &"shrink", "amount": 1})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.B,
			Reveal.all_or_none(g, s, pid, Mtg.ManaColor.B, not Reveal.ours(g, pid, t)))
		if n <= 0 or not g.is_present(i):
			return
		g.continuous.add_until_eot_pump(i.id, -n, -n)
		g.log_line("%s gives %s -%d/-%d until end of turn" % [s.data.card_name, i.data.card_name, n, n])
		g.recalculate()
	func describe() -> String:
		return "reveal any number of black cards in your hand; target creature gets -X/-X until end of turn, where X is the number of cards revealed this way"


## Cinder: "<This> deals X damage to any target."
class RevealBurn extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.R, "per_card": &"damage", "amount": 1})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.R,
			Reveal.all_or_none(g, s, pid, Mtg.ManaColor.R, not Reveal.ours(g, pid, t)))
		if n > 0:
			g.deal_damage(s, t, n)
	func describe() -> String:
		return "reveal any number of red cards in your hand; deals X damage to any target, where X is the number of cards revealed this way"


## Ivy: "Target creature gets +X/+X until end of turn."
class RevealPump extends PumpEffect:
	func _init() -> void:
		super(0, 0)
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.G, "per_card": &"pump", "amount": 1})
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.G,
			Reveal.all_or_none(g, s, pid, Mtg.ManaColor.G, Reveal.ours(g, pid, t)))
		if n <= 0 or not g.is_present(i):
			return
		g.continuous.add_until_eot_pump(i.id, n, n)
		g.log_line("%s gives %s +%d/+%d until end of turn" % [s.data.card_name, i.data.card_name, n, n])
		g.recalculate()
	func describe() -> String:
		return "reveal any number of green cards in your hand; target creature gets +X/+X until end of turn, where X is the number of cards revealed this way"


## Rofellos's Gift: one enchantment card per card revealed, as many as
## the graveyard holds, chosen one at a time (hint: the costliest first).
class RevealRaise extends EffectBase:
	func _init() -> void:
		with_ai_role(&"reveal_from_hand", {"color": Mtg.ManaColor.G, "per_card": &"raise_enchantment", "amount": 1})
		ai_helpful = true
	static func enchantments(g: MtgGame, pid: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for card in g.players[pid].graveyard:
			if card.data.is_type(Mtg.CardType.ENCHANTMENT): out.append(card)
		out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var va := a.data.cost.mana_value()
			var vb := b.data.cost.mana_value()
			if va != vb: return va > vb
			return a.id < b.id)
		return out
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var hint := mini(Reveal.cards(g, s, pid, Mtg.ManaColor.G).size(), RevealRaise.enchantments(g, pid).size())
		var n := Reveal.ask(g, s, pid, Mtg.ManaColor.G, hint)
		for k in n:
			var pool := RevealRaise.enchantments(g, pid)
			if pool.is_empty():
				break
			var pick := g.agents[pid].choose_card(g, pid, pool,
				"%s: return an enchantment card from your graveyard to your hand (%d of %d)" % [
					s.data.card_name, k + 1, n], false, false, true)
			if pick == null or not pool.has(pick): pick = pool[0]
			g.return_from_graveyard_to_hand(pick)
	func describe() -> String:
		return "reveal any number of green cards in your hand; return an enchantment card from your graveyard to your hand for each card revealed this way"
