extends RefCounted
## Urza's Destiny (_creatures, Pack 10). Creatures with activated or static
## abilities of their own.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape (Elvish Piper, Norwood Priestess's
## `green_creature_from_hand`). The scaffolds print what
## CardData.with_keywords carries except Metathran Soldier's "can't be
## blocked", added here; shroud is a layer-6 static. The "as long as"
## keyword grants are layer-6 statics too (CR 613.1f), so Humility's loss
## and the floating grants keep their order. Helpers shared with Urza's
## Saga live in cards/sets/usg/_creatures.gd. tests/cards/test_pack_10_B3_*.gd
## pin each card's distinguishing clause and its edges.
const F := preload("res://cards/sets/fem/_rules.gd")
const U := preload("res://cards/sets/usg/_creatures.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Capashen Knight":
			# The scaffold prints first strike.
			c.activated(ActivatedAbility.new("{1}{W}", false, [PumpEffect.new(1, 0).self_buff()],
				"{1}{W}: This creature gets +1/+0 until end of turn."))
		"Capashen Templar":
			c.activated(ActivatedAbility.new("{W}", false, [PumpEffect.new(0, 1).self_buff()],
				"{W}: This creature gets +0/+1 until end of turn."))
		"Field Surgeon":
			# "Tap an untapped creature you control" is not {T}: a
			# summoning-sick creature may pay it, the Surgeon itself
			# included (CR 302.6; Tradewind Rider's cost without the {T}).
			var mend := ActivatedAbility.new("", false, [PreventDamageEffect.new(1).target_creature()],
				"Tap an untapped creature you control: Prevent the next 1 damage that would be dealt to target creature this turn.")
			mend.tap_permanent_filter = F._creature
			mend.tap_permanent_count = 1
			c.activated(mend)
		"Master Healer":
			c.activated(ActivatedAbility.new("", true, [PreventDamageEffect.new(4).any_target()],
				"{T}: Prevent the next 4 damage that would be dealt to any target this turn."))
		"Serra Advocate":
			# The scaffold prints flying.
			var lift := PumpEffect.new(2, 2)
			lift.target_spec = U.in_combat_creature()
			c.activated(ActivatedAbility.new("", true, [lift],
				"{T}: Target attacking or blocking creature gets +2/+2 until end of turn."))
		# ----------------------------------------------------------- blue
		"Bubbling Beebles":
			c.static_ability(StaticAbility.new(_beebles,
				"This creature can't be blocked as long as defending player controls an enchantment.").changing_abilities())
		"Fledgling Osprey":
			c.static_ability(StaticAbility.new(_osprey,
				"This creature has flying as long as it's enchanted.").changing_abilities())
		"Metathran Elite":
			c.static_ability(StaticAbility.new(_elite,
				"This creature can't be blocked as long as it's enchanted.").changing_abilities())
		"Metathran Soldier":
			# A printed ability the scaffold does not carry.
			c.with_keywords([Mtg.Keyword.UNBLOCKABLE])
		"Temporal Adept":
			c.activated(ActivatedAbility.new("{U}{U}{U}", true,
				[ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))],
				"{U}{U}{U}, {T}: Return target permanent to its owner's hand."))
		# ---------------------------------------------------------- black
		"Phyrexian Monitor":
			c.activated(ActivatedAbility.new("{B}", false, [RegenerateEffect.new()], "{B}: Regenerate this creature."))
		"Slinking Skirge":
			# The scaffold prints flying.
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice this creature: Draw a card.").with_sacrifice_cost())
		# ------------------------------------------------------------ red
		"Bloodshot Cyclops":
			# "A creature" includes the Cyclops itself; the damage is
			# still dealt by it, as it last existed (CR 608.2h).
			c.activated(ActivatedAbility.new("", true, [Hurl.new()],
				"{T}, Sacrifice a creature: This creature deals damage equal to the sacrificed creature's power to any target.") \
				.with_sacrifice_of("creature", F._creature).may_sacrifice_itself())
		"Colos Yearling":
			# The scaffold prints mountainwalk.
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Hulking Ogre":
			c.static_ability(StaticAbility.new(_cant_block, "This creature can't block."))
		# ---------------------------------------------------------- green
		"Ancient Silverback":
			c.activated(ActivatedAbility.new("{G}", false, [RegenerateEffect.new()], "{G}: Regenerate this creature."))
		"Elvish Lookout":
			c.static_ability(StaticAbility.new(U.shroud, "Shroud.").changing_abilities())
		"Elvish Piper":
			# Putting a creature onto the battlefield is not casting it.
			# Role `green_creature_from_hand` (Norwood Priestess's reading,
			# engine/ai/second_age_tactics.gd): the fair AI prices the green
			# creature cards of its own hand — a narrower reading than the
			# card, which takes any creature card.
			c.activated(ActivatedAbility.new("{G}", true,
				[F.Action.new(_piper, "you may put a creature card from your hand onto the battlefield", null, true) \
					.with_ai_role(&"green_creature_from_hand")],
				"{G}, {T}: You may put a creature card from your hand onto the battlefield."))
		"Taunting Elf":
			c.static_ability(StaticAbility.new(_taunt, "All creatures able to block this creature do so."))
		"Yavimaya Enchantress":
			c.static_ability(StaticAbility.new(_enchantress,
				"This creature gets +1/+1 for each enchantment on the battlefield."))
		_: return false
	return true


# ------------------------------------------------------------- filters --

static func _anything(_i: CardInstance) -> bool:
	return true

## An enchantment on the battlefield that is not phased out (CR 702.26b).
static func _live_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ENCHANTMENT) and not i.phased_out


# -------------------------------------------------------------- statics --

## "Defending player" in a two-seat duel: the Beebles' controller's
## opponent, the only player it can attack.
static func _beebles(g: MtgGame, s: CardInstance) -> void:
	if s.cur_keywords.has(Mtg.Keyword.UNBLOCKABLE):
		return
	for i in g.players[g.opponent_of(s.controller_id)].battlefield:
		if _live_enchantment(i):
			s.cur_keywords.append(Mtg.Keyword.UNBLOCKABLE)
			return

static func _osprey(g: MtgGame, s: CardInstance) -> void:
	if g.is_enchanted(s) and not s.cur_keywords.has(Mtg.Keyword.FLYING):
		s.cur_keywords.append(Mtg.Keyword.FLYING)

static func _elite(g: MtgGame, s: CardInstance) -> void:
	if g.is_enchanted(s) and not s.cur_keywords.has(Mtg.Keyword.UNBLOCKABLE):
		s.cur_keywords.append(Mtg.Keyword.UNBLOCKABLE)

static func _cant_block(_g: MtgGame, s: CardInstance) -> void:
	s.cur_cant_block_filter = _anything

## Lure on itself (CR 509.1c): every creature able to block it must.
static func _taunt(_g: MtgGame, s: CardInstance) -> void:
	s.cur_must_be_blocked = true
	s.cur_must_be_blocked_by_all = true

## Every enchantment on the battlefield, both players' — an Aura, an
## animated one (Opalescence) — read after the type layer (an untagged,
## layer 7c static).
static func _enchantress(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in g.all_battlefield():
		if _live_enchantment(i):
			n += 1
	s.cur_power += n
	s.cur_toughness += n


# -------------------------------------------------------------- actions --

## Elvish Piper: "you may" — declining is offered. The creature cards of
## the activator's hand, the costliest first (the hint takes the first).
static func _piper(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var bodies: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_creature():
			bodies.append(card)
	if bodies.is_empty():
		return
	bodies.sort_custom(_costlier)
	var pick := g.agents[pid].choose_card(g, pid, bodies,
		"Elvish Piper: you may put a creature card from your hand onto the battlefield", true)
	if pick != null and bodies.has(pick):
		g.put_from_hand_into_play(pick, pid)

static func _costlier(a: CardInstance, b: CardInstance) -> bool:
	return a.data.cost.mana_value() > b.data.cost.mana_value()


# -------------------------------------------------------------- effects --

## Bloodshot Cyclops: the damage is the sacrificed creature's power, read
## off THIS activation's cost record (last known information, CR 608.2h);
## the Cyclops is the source even when it was the creature thrown (Mogg
## Fanatic's shape). A DamageEffect, so the fair AI reads the shot.
class Hurl extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()

	func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
			_x_value := 0) -> void:
		var n := maxi(0, int(game.cost_paid("_sacrificed_power", 0)))
		if n > 0:
			game.deal_damage(source, target, n)

	func describe() -> String:
		return "deals damage equal to the sacrificed creature's power to any target"
