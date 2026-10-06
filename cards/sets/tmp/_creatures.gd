extends RefCounted
## Tempest (_creatures, Pack 9). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape (Giant Crab's and Selenia's answer to a targeted
## spell, `self_bounce`). tests/cards/test_pack_9_B4_*.gd pin each card's
## distinguishing clause and its edges.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const WC := preload("res://cards/sets/wth/_creatures.gd")

## The colour bits protection can name (Mtg.ManaColor W|U|B|R|G).
const COLOR_BITS := 31
## Escaped Shapeshifter's three copied keywords; protection is its fourth
## clause and lives in a static of its own (see [method _shapeshifter_protection]).
const SHAPESHIFTER_KEYWORDS: Array[int] = [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE]

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Advance Scout":
			# The scaffold prints first strike.
			c.activated(ActivatedAbility.new("{W}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE])],
				"{W}: Target creature gains first strike until end of turn."))
		"Auratog":
			# Any enchantment you control, an Aura on an opposing creature
			# included (CR 701.17a: you sacrifice only what you control).
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()],
				"Sacrifice an enchantment: This creature gets +2/+2 until end of turn.") \
				.with_sacrifice_of("enchantment", _enchantment))
		"Clergy en-Vec":
			# PreventDamageEffect is of the 1997 prevention family (§6.8).
			c.activated(ActivatedAbility.new("", true, [PreventDamageEffect.new(1).any_target()],
				"{T}: Prevent the next 1 damage that would be dealt to any target this turn."))
		"Knight of Dawn":
			# The colour is chosen as the ability resolves (CR 608.2d); the
			# scaffold prints first strike. Role `self_bounce`: the fair AI's
			# answer to an opposing spell or ability aimed at the Knight —
			# the hint ([method _dawn_hint]) names that object's colour, so
			# the target becomes illegal (CR 702.16b, 608.2b).
			c.activated(ActivatedAbility.new("{W}{W}", false,
				[F.Action.new(_dawn, "this creature gains protection from the color of your choice until end of turn", null, true).with_ai_role(&"self_bounce")],
				"{W}{W}: This creature gains protection from the color of your choice until end of turn."))
		"Marble Titan":
			# Meekstone's static: it asks about a LIVE power, so it waits for
			# every P/T layer (StaticAbility.reading_pt, CR 613.8). The Titan
			# itself (3/3) is one of the creatures it locks.
			c.static_ability(StaticAbility.new(_titan,
				"Creatures with power 3 or greater don't untap during their controllers' untap steps.").reading_pt())
		"Master Decoy":
			c.activated(ActivatedAbility.new("{W}", true, [TapEffect.new(TargetSpec.creature())],
				"{W}, {T}: Tap target creature."))
		"Orim, Samite Healer":
			c.activated(ActivatedAbility.new("", true, [PreventDamageEffect.new(3).any_target()],
				"{T}: Prevent the next 3 damage that would be dealt to any target this turn."))
		# ----------------------------------------------------------- blue
		"Escaped Shapeshifter":
			# Layer 6, decided by layer-6 abilities of OTHER creatures, so it
			# is applied after the rest of the layer (CR 613.8a,
			# StaticAbility.reading_abilities — Chaosphere's shape).
			c.static_ability(StaticAbility.new(_shapeshifter_keywords,
				"As long as an opponent controls a creature with flying not named Escaped Shapeshifter, this creature has flying. The same is true for first strike and trample.") \
				.changing_abilities().reading_abilities())
			c.static_ability(StaticAbility.new(_shapeshifter_protection,
				"As long as an opponent controls a creature with protection from a color not named Escaped Shapeshifter, this creature has protection from that color.").reading_pt())
		"Fylamarid":
			# The scaffold prints flying.
			c.static_ability(StaticAbility.new(_fylamarid, "This creature can't be blocked by blue creatures."))
			c.activated(ActivatedAbility.new("{U}", false,
				[ChangeColorEffect.new(Mtg.ManaColor.U, TargetSpec.creature()).until_end_of_turn()],
				"{U}: Target creature becomes blue until end of turn."))
		"Giant Crab":
			# Role `self_bounce`: the fair AI's answer to an opposing spell
			# that targets this creature — shroud makes that target illegal
			# (CR 608.2b), the same shape as returning it to hand.
			c.activated(ActivatedAbility.new("{U}", false,
				[F.Action.new(_crab, "this creature gains shroud until end of turn", null, true).with_ai_role(&"self_bounce")],
				"{U}: This creature gains shroud until end of turn."))
		"Manta Riders":
			# Role `self_keyword` (Phelddagrif's): an attacker that lacks the
			# keyword buys it before blocks.
			c.activated(ActivatedAbility.new("{U}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff().with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.FLYING})],
				"{U}: This creature gains flying until end of turn."))
		"Mawcor", "Rootwater Hunter":
			c.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()],
				"{T}: This creature deals 1 damage to any target."))
		"Rootwater Diver":
			var salvage := ReturnFromGraveyardEffect.new()
			salvage.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
				"target artifact card from your graveyard", _artifact_card)
			c.activated(ActivatedAbility.new("", true, [salvage],
				"{T}, Sacrifice this creature: Return target artifact card from your graveyard to your hand.").with_sacrifice_cost())
		"Tradewind Rider":
			# "Tap two untapped creatures you control" is not {T}: summoning
			# sick creatures may pay it, the Rider itself may not (its own
			# {T} is already in the cost) — CR 302.6.
			var trade := ActivatedAbility.new("", true, [ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT))],
				"{T}, Tap two untapped creatures you control: Return target permanent to its owner's hand.")
			trade.tap_permanent_filter = F._creature
			trade.tap_permanent_count = 2
			c.activated(trade)
		"Wind Dancer":
			c.activated(ActivatedAbility.new("", true, [PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])],
				"{T}: Target creature gains flying until end of turn."))
		# ---------------------------------------------------------- black
		"Bounty Hunter":
			# The counter itself is a marker with no P/T meaning, so it is a
			# card-local effect rather than a CounterMarkerEffect (which the
			# AI reads as a pump).
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_bounty, "put a bounty counter on target nonblack creature",
					TargetSpec.creature("target nonblack creature", _nonblack)) \
					.with_ai_role(&"bounty_mark", {"kind": "bounty"})],
				"{T}: Put a bounty counter on target nonblack creature."))
			c.activated(ActivatedAbility.new("", true,
				[DestroyEffect.new(TargetSpec.creature("target creature with a bounty counter on it", _bountied))],
				"{T}: Destroy target creature with a bounty counter on it."))
		"Carrionette":
			c.activated(ActivatedAbility.new("{2}{B}{B}", false, [CarrionetteExile.new()],
				"{2}{B}{B}: Exile this card and target creature unless that creature's controller pays {2}. Activate only if this card is in your graveyard.") \
				.from_graveyard())
		"Coffin Queen":
			c.with_may_skip_untap()
			c.activated(ActivatedAbility.new("{2}{B}", true, [CoffinRaise.new()],
				"{2}{B}, {T}: Put target creature card from a graveyard onto the battlefield under your control. When this creature becomes untapped or you lose control of this creature, exile that creature."))
		"Darkling Stalker":
			c.activated(ActivatedAbility.new("{B}", false, [RegenerateEffect.new()], "{B}: Regenerate this creature."))
			c.activated(ActivatedAbility.new("{B}", false, [PumpEffect.new(1, 1).self_buff()],
				"{B}: This creature gets +1/+1 until end of turn."))
		"Marsh Lurker":
			# Role `self_keyword`, as Manta Riders; the Swamp is priced as
			# the sacrifice cost it is.
			c.activated(ActivatedAbility.new("", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FEAR]).self_buff().with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.FEAR})],
				"Sacrifice a Swamp: This creature gains fear until end of turn.") \
				.with_sacrifice_of("Swamp", F._subtype.bind("swamp")))
		"Minion of the Wastes":
			# Nameless Race's shape (drk/nameless_race.gd) without its ceiling.
			c.as_it_enters(_minion_pay)
			c.static_ability(StaticAbility.new(_minion_size,
				"Minion of the Wastes's power and toughness are each equal to the life paid as it entered.").setting_base_pt())
		"Pit Imp":
			c.activated(ActivatedAbility.new("{B}", false, [PumpEffect.new(1, 0).self_buff()],
				"{B}: This creature gets +1/+0 until end of turn. Activate no more than twice each turn.").per_turn(2))
		"Rats of Rath":
			var own := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land you control",
				_artifact_creature_or_land).with_source_filter(F._own)
			c.activated(ActivatedAbility.new("{B}", false, [DestroyEffect.new(own)],
				"{B}: Destroy target artifact, creature, or land you control."))
		"Screeching Harpy":
			c.activated(ActivatedAbility.new("{1}{B}", false, [RegenerateEffect.new()], "{1}{B}: Regenerate this creature."))
		"Skyshroud Vampire":
			var feast := ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()],
				"Discard a creature card: This creature gets +2/+2 until end of turn.").with_discard_cost(1)
			feast.discard_filter = _creature_card
			feast.discard_filter_desc = "creature card"
			c.activated(feast)
		"Souldrinker":
			# The life is a COST (CR 118.3); the counter lands only on the
			# object that paid it (WC.SelfCounter, CR 400.7).
			c.activated(ActivatedAbility.new("", false, [WC.SelfCounter.new("+1/+1")],
				"Pay 3 life: Put a +1/+1 counter on this creature.").with_life_cost(3))
		# ------------------------------------------------------------ red
		"Canyon Drake":
			c.activated(ActivatedAbility.new("{1}", false, [PumpEffect.new(2, 0).self_buff()],
				"{1}, Discard a card at random: This creature gets +2/+0 until end of turn.").with_random_discard_cost(1))
		"Firefly", "Sandstone Warrior":
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Fireslinger":
			c.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target(), DamageEffect.new(1).to_controller()],
				"{T}: This creature deals 1 damage to any target and 1 damage to you."))
		"Flowstone Giant", "Flowstone Wyvern":
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(2, -2).self_buff()],
				"{R}: This creature gets +2/-2 until end of turn."))
		"Mogg Fanatic":
			# The damage comes from the sacrificed Fanatic as it last existed
			# (CR 608.2h).
			c.activated(ActivatedAbility.new("", false, [DamageEffect.new(1).any_target()],
				"Sacrifice this creature: It deals 1 damage to any target.").with_sacrifice_cost())
		"Mogg Raider":
			# The Raider is a Goblin itself and may pay with its own body.
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(1, 1)],
				"Sacrifice a Goblin: Target creature gets +1/+1 until end of turn.") \
				.with_sacrifice_of("Goblin", F._subtype.bind("goblin")).may_sacrifice_itself())
		"Mogg Squad":
			c.static_ability(StaticAbility.new(_mogg_squad,
				"This creature gets -1/-1 for each other creature on the battlefield."))
		"Opportunist":
			c.activated(ActivatedAbility.new("", true,
				[DamageEffect.new(1).target_creature("target creature that was dealt damage this turn", _was_damaged)],
				"{T}: This creature deals 1 damage to target creature that was dealt damage this turn."))
		"Pallimud":
			# Haunting Apparition's shape (mir/_creatures.gd): the chosen
			# seat is fixed as it enters; the CDA counts live (CR 604.3).
			c.as_it_enters(_choose_opponent)
			c.static_ability(StaticAbility.new(_pallimud,
				"Pallimud's power is equal to the number of tapped lands the chosen player controls.").setting_base_pt())
		"Starke of Rath":
			var victim := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or creature", _artifact_or_creature)
			c.activated(ActivatedAbility.new("", true, [StarkeDestroy.new(victim)],
				"{T}: Destroy target artifact or creature. That permanent's controller gains control of Starke."))
		# ---------------------------------------------------------- green
		"Crazed Armodon":
			c.activated(ActivatedAbility.new("{G}", false, [PumpEffect.new(3, 0, [Mtg.Keyword.TRAMPLE]).self_buff(),
				F.Action.new(_armodon_doom, "destroy this creature at the beginning of the next end step")],
				"{G}: This creature gets +3/+0 and gains trample until end of turn. Destroy this creature at the beginning of the next end step. Activate only once each turn.").per_turn(1))
		"Eladamri, Lord of Leaves":
			# Both grants are layer 6 (CR 613.1f); "Other Elves" is every
			# other Elf permanent, the forestwalk only Elf creatures.
			c.static_ability(StaticAbility.new(_eladamri,
				"Other Elf creatures have forestwalk. Other Elves have shroud.").changing_abilities())
		"Heartwood Giant":
			c.activated(ActivatedAbility.new("", true,
				[DamageEffect.new(2).target_player(Callable(), "target player or planeswalker")],
				"{T}, Sacrifice a Forest: This creature deals 2 damage to target player or planeswalker.") \
				.with_sacrifice_of("Forest", F._subtype.bind("forest")))
		"Krakilin":
			# "Enters with X +1/+1 counters" — the X of the spell that put it
			# there (Rock Hydra's shape); any other arrival brings X = 0.
			c.as_it_enters(_x_counters)
			c.activated(ActivatedAbility.new("{1}{G}", false, [RegenerateEffect.new()], "{1}{G}: Regenerate this creature."))
		"Pincher Beetles":
			c.static_ability(StaticAbility.new(_shroud, "Shroud.").changing_abilities())
		"Rootwalla":
			c.activated(ActivatedAbility.new("{1}{G}", false, [PumpEffect.new(2, 2).self_buff()],
				"{1}{G}: This creature gets +2/+2 until end of turn. Activate only once each turn.").per_turn(1))
		"Seeker of Skybreak":
			c.activated(ActivatedAbility.new("", true, [UntapEffect.new(TargetSpec.creature())],
				"{T}: Untap target creature."))
		"Skyshroud Ranger":
			# Putting a land onto the battlefield is not playing one: no land
			# drop is used (CR 305.4).
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_ranger, "you may put a land card from your hand onto the battlefield", null, true) \
					.with_ai_role(&"land_from_hand")],
				"{T}: You may put a land card from your hand onto the battlefield. Activate only as a sorcery.") \
				.only_if(MA.sorcery_speed))
		"Skyshroud Troll":
			c.activated(ActivatedAbility.new("{1}{G}", false, [RegenerateEffect.new()], "{1}{G}: Regenerate this creature."))
		# ----------------------------------------------------------- gold
		"Dracoplasm":
			# The scaffold prints flying.
			c.as_it_enters(_dracoplasm_feed)
			c.static_ability(StaticAbility.new(_dracoplasm_size,
				"This creature's power is the total power of the creatures sacrificed as it entered and its toughness is their total toughness.").setting_base_pt())
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Ranger en-Vec":
			# The scaffold prints first strike.
			c.activated(ActivatedAbility.new("{G}", false, [RegenerateEffect.new()], "{G}: Regenerate this creature."))
		"Selenia, Dark Angel":
			# The 2 life is a cost (CR 118.3). Role `self_bounce`: the fair
			# AI's answer to an opposing spell that targets her.
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_selenia, "return Selenia to its owner's hand", null, true).with_ai_role(&"self_bounce")],
				"Pay 2 life: Return Selenia to its owner's hand.").with_life_cost(2))
		"Vhati il-Dal":
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_vhati, "until end of turn, target creature has base power 1 or base toughness 1", TargetSpec.creature())],
				"{T}: Until end of turn, target creature has base power 1 or base toughness 1."))
		_: return false
	return true


# ------------------------------------------------------------- filters --

static func _enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ENCHANTMENT)

static func _nonblack(i: CardInstance) -> bool:
	return (i.cur_colors & Mtg.ManaColor.B) == 0

static func _bountied(i: CardInstance) -> bool:
	return int(i.counters.get("bounty", 0)) > 0

static func _not_blue(blocker: CardInstance) -> bool:
	return (blocker.cur_colors & Mtg.ManaColor.U) == 0

## A card in a graveyard or a hand has only its printed characteristics.
static func _artifact_card(i: CardInstance) -> bool:
	return i.data.is_type(Mtg.CardType.ARTIFACT)

static func _creature_card(i: CardInstance) -> bool:
	return i.data.is_creature()

static func _artifact_creature_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()

static func _artifact_or_creature(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature()

## "Was dealt damage this turn" — the per-turn ledger the engine keeps on
## the object (CardInstance.damaged_by_this_turn, cleared at cleanup and
## when it leaves the battlefield). Damage that was prevented was not dealt.
static func _was_damaged(i: CardInstance) -> bool:
	return not i.damaged_by_this_turn.is_empty()

## The lowest colour bit of [param mask], WUBRG order (0 = none).
static func _first_color(mask: int) -> int:
	for color in Mtg.WUBRG:
		if (mask & color) != 0:
			return color
	return 0


# -------------------------------------------------------------- statics --

static func _titan(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.cur_power >= 3:
			i.cur_skips_untap = true

static func _fylamarid(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "nonblue creatures", "filter": _not_blue})

static func _shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true

static func _mogg_squad(g: MtgGame, s: CardInstance) -> void:
	var others := 0
	for i in g.all_battlefield():
		if i != s and i.is_creature():
			others += 1
	s.cur_power -= others
	s.cur_toughness -= others

static func _eladamri(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i == s or not i.has_subtype("elf"):
			continue
		i.cur_shroud = true
		if i.is_creature() and not i.cur_landwalk.has("forest"):
			i.cur_landwalk.append("forest")

## The creatures an opponent of [param s]'s controller controls, apart from
## any named Escaped Shapeshifter (the printed exclusion, which is also what
## keeps two of them from feeding each other).
static func _shapeshifter_models(g: MtgGame, s: CardInstance) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.controller_id != s.controller_id and i.is_creature() \
				and i.data.card_name != "Escaped Shapeshifter":
			out.append(i)
	return out

static func _shapeshifter_keywords(g: MtgGame, s: CardInstance) -> void:
	var models := _shapeshifter_models(g, s)
	for keyword in SHAPESHIFTER_KEYWORDS:
		if s.cur_keywords.has(keyword):
			continue
		for i in models:
			if i.has_keyword(keyword):
				s.cur_keywords.append(keyword)
				break

## THE PROTECTION HALF, read in the pipeline's last static pass. Protection
## is layer 6 like the three keywords, but the engine merges two of its
## sources AFTER layer 6 — the floating until-end-of-turn grants (a Knight
## of Dawn's, a Goblin Wizard's; ContinuousEffects.recalculate pass 3a3)
## and the Ward Auras' booked grants (CardInstance.cur_aura_protection,
## merged at the very end). A layer-6 static would not see either, so this
## half rides the pass that runs after every one of those writers
## (StaticAbility.reading_pt — the flag's pass, not its P/T meaning) and
## reads the Ward books itself. Nothing reads protection in between, so the
## answer is the one CR 613.8a's dependency gives.
static func _shapeshifter_protection(g: MtgGame, s: CardInstance) -> void:
	var mask := 0
	for i in _shapeshifter_models(g, s):
		mask |= i.cur_protection
		for warded in i.cur_aura_protection.values():
			mask |= int(warded)
	s.cur_protection |= mask & COLOR_BITS

static func _minion_size(_g: MtgGame, s: CardInstance) -> void:
	var n: int = maxi(0, int(s.memory.get("paid", 0)))
	s.cur_power = n
	s.cur_toughness = n

static func _dracoplasm_size(_g: MtgGame, s: CardInstance) -> void:
	var meal: Array = s.memory.get("dracoplasm", [0, 0])
	s.cur_power = int(meal[0])
	s.cur_toughness = int(meal[1])

static func _pallimud(g: MtgGame, s: CardInstance) -> void:
	var who := int(s.memory.get("chosen_player", -1))
	var n := 0
	if who >= 0 and who < g.players.size():
		for i in g.players[who].battlefield:
			if i.is_land() and i.tapped:
				n += 1
	s.cur_power = n


# --------------------------------------------------------- as it enters --

## "As this creature enters, pay any amount of life" (CR 614.12, CR 119.4:
## no more than you have). Size first, then the payment — the life loss
## runs the state-based actions and a printed 0/0 would not survive them.
static func _minion_pay(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var life: int = g.players[controller].life
	var paid := 0
	if life > 0:
		paid = g.agents[controller].choose_number(g, controller, 0, life,
			"Pay how much life to Minion of the Wastes?",
			clampi(mini(life / 2, life - 5), 0, life))
	g._rec(inst, &"memory")
	inst.memory["paid"] = paid
	g.recalculate()
	if paid > 0:
		g.adjust_life(controller, -paid)

## "As this creature enters, sacrifice any number of creatures" — any
## creatures its controller controls, never itself. The total power and
## toughness are those of the bodies as they were sacrificed (CR 608.2h);
## they are summed and booked BEFORE the sacrifice, which is one event
## (simultaneous), so the Dracoplasm never shows its printed 0/0 to the
## state-based actions. The offered order (the hint takes the first): the
## creatures without flying, the smallest first.
static func _dracoplasm_feed(g: MtgGame, inst: CardInstance, controller: int) -> void:
	var food: Array[CardInstance] = []
	for i in g.players[controller].battlefield:
		if i != inst and i.is_creature():
			food.append(i)
	food.sort_custom(_lesser_meal)
	var hint := 0
	for i in food:
		if not i.has_keyword(Mtg.Keyword.FLYING):
			hint += 1
	if hint == 0 and not food.is_empty():
		hint = 1
	var count := 0
	if not food.is_empty():
		count = g.agents[controller].choose_number(g, controller, 0, food.size(),
			"Sacrifice how many creatures to Dracoplasm?", hint)
	var meal: Array[CardInstance] = []
	for n in count:
		if food.is_empty():
			break
		var pick := g.agents[controller].choose_card(g, controller, food,
			PlayerChoice.sacrifice_prompt("creature"), false, false, true)
		if pick == null or not food.has(pick):
			pick = food[0]
		food.erase(pick)
		meal.append(pick)
	var power := 0
	var toughness := 0
	for body in meal:
		power += body.cur_power
		toughness += body.cur_toughness
	g._rec(inst, &"memory")
	inst.memory["dracoplasm"] = [power, toughness]
	g.recalculate()
	if meal.is_empty():
		return
	g.begin_simultaneous()
	for body in meal:
		g.sacrifice_permanent(body)
	g.end_simultaneous()

static func _lesser_meal(a: CardInstance, b: CardInstance) -> bool:
	var a_flies := a.has_keyword(Mtg.Keyword.FLYING)
	if a_flies != b.has_keyword(Mtg.Keyword.FLYING):
		return not a_flies
	return a.cur_power + a.cur_toughness < b.cur_power + b.cur_toughness

static func _choose_opponent(g: MtgGame, s: CardInstance, pid: int) -> void:
	var chosen := g.choose_opponent(pid, s)
	g._rec(s, &"memory")
	s.memory["chosen_player"] = chosen

static func _x_counters(g: MtgGame, inst: CardInstance, _pid: int) -> void:
	var x := int(inst.memory.get("x_value", 0))
	if x > 0:
		g.add_counters(inst, "+1/+1", x)


# -------------------------------------------------------------- actions --

## Knight of Dawn. The colour is the controller's choice, asked through the
## DecisionAgent funnel; the hint reads public things only — an opposing
## spell or ability on the stack that targets the Knight, then the
## creatures it is fighting, then the commonest colour among the opposing
## creatures.
static func _dawn(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not MA.same_activation(g, s):
		return
	var hint := _dawn_hint(g, s, pid)
	var color := _first_color(g.agents[pid].choose_color(g, pid,
		"Knight of Dawn gains protection from which color?", hint))
	if color == 0:
		color = hint
	g.continuous.add_until_eot_protection(s.id, color)
	g.recalculate()

static func _dawn_hint(g: MtgGame, s: CardInstance, pid: int) -> int:
	for at in range(g.stack.size() - 1, -1, -1):
		var item: StackItem = g.stack[at]
		if item.controller == pid or item.card == null:
			continue
		for ref in item.targets:
			if not ref.is_player and ref.instance_id == s.id and _first_color(item.card.cur_colors) != 0:
				return _first_color(item.card.cur_colors)
	var fighting: Array[int] = g.combat.blockers_of(s.id)
	fighting.append_array(g.combat.attackers_blocked_by(s.id))
	for id in fighting:
		var foe := g.find_instance(id)
		if foe != null and _first_color(foe.cur_colors) != 0:
			return _first_color(foe.cur_colors)
	var best := Mtg.ManaColor.R
	var most := 0
	for color in Mtg.WUBRG:
		var n := 0
		for i in g.players[g.opponent_of(pid)].battlefield:
			if i.is_creature() and (i.cur_colors & color) != 0:
				n += 1
		if n > most:
			most = n
			best = color
	return best

static func _crab(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, x: int) -> void:
	if MA.same_activation(g, s):
		F._grant_shroud(g, s, pid, TargetRef.card(s), x)

static func _bounty(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if g.is_present(i):
		g.add_counters(i, "bounty")

static func _armodon_doom(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MA.same_activation(g, s):
		g.doom_at_next_end_step(s)

static func _ranger(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var lands: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_land():
			lands.append(card)
	if lands.is_empty():
		return
	var pick := g.agents[pid].choose_card(g, pid, lands,
		"Skyshroud Ranger: you may put a land card from your hand onto the battlefield", true)
	if pick != null and lands.has(pick):
		g.put_from_hand_into_play(pick, pid)

static func _selenia(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MA.same_activation(g, s):
		g.return_to_hand(s)

## Vhati il-Dal: power or toughness is chosen as the ability resolves. The
## hint: an opposing creature with damage marked loses its toughness (it
## dies), any other opposing creature its power; our own keeps toughness.
static func _vhati(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var victim := g.find_instance(t.instance_id)
	if not g.is_present(victim):
		return
	var hint := 0
	if victim.controller_id != pid and victim.damage > 0:
		hint = 1
	var labels: Array[String] = ["Base power 1", "Base toughness 1"]
	var pick := g.agents[pid].choose_option(g, pid, labels,
		"Vhati il-Dal: %s has base power 1 or base toughness 1 until end of turn?" % victim.data.card_name, hint)
	if pick == 1:
		g.continuous.add_until_eot_base_pt(victim.id, -1, 1)
	else:
		g.continuous.add_until_eot_base_pt(victim.id, 1, -1)
	g.recalculate()


# -------------------------------------------------------------- effects --

## Carrionette: "Exile this card and target creature unless that creature's
## controller pays {2}." The creature's controller decides as the ability
## resolves; paying saves both. A Carrionette that has left the graveyard
## since (a new object, CR 400.7) is not exiled, but the creature still is.
## An ExileEffect, so the fair AI reads it as removal.
class CarrionetteExile extends ExileEffect:
	func _init() -> void:
		super(TargetSpec.creature())

	func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
			_x_value := 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if not game.is_present(victim):
			return
		var payer := victim.controller_id
		if EffectBase.unless_paid(game, payer, ManaCost.parse("{2}"),
				"Pay {2} to keep %s (and Carrionette) from exile?" % victim.data.card_name):
			return
		if source.zone == Mtg.Zone.GRAVEYARD \
				and source.graveyard_entry == int(game.cost_paid("_source_graveyard_entry", -1)):
			game.exile_from_graveyard(source)
		game.exile_permanent(victim)

	func describe() -> String:
		return "exiles this card and target creature unless that creature's controller pays {2}"


## Coffin Queen: the creature card enters under the activator's control,
## then a DELAYED trigger (CR 603.7) watches the Queen — the same object
## (its timestamp) — becoming untapped, changing controller away from the
## activator, or leaving the battlefield (which loses control of it too),
## and exiles that creature if it is still the same object. The trigger is
## created as the ability resolves, so an untap that already happened
## before then does not fire it. A ReturnFromGraveyardEffect, so the fair AI
## reads the reanimation as one.
class CoffinRaise extends ReturnFromGraveyardEffect:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD,
			"target creature card from a graveyard")
		to_battlefield_mode = true

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			_x_value := 0) -> void:
		var card := game.find_instance(target.instance_id)
		if card == null or card.zone != Mtg.Zone.GRAVEYARD:
			return
		game.reanimate(card, controller)
		if not game.is_present(card):
			return
		var queen_stamp := int(game.cost_paid("_source_timestamp", -1))
		if source.zone != Mtg.Zone.BATTLEFIELD or source.layer_timestamp != queen_stamp:
			return   # this Queen is gone: nothing can untap or leave any more
		game._rec(source, &"memory")
		source.memory["holding"] = card.id   # the untap step's "don't untap" hint
		var watch := TriggeredAbility.new(Mtg.EventType.BECAME_UNTAPPED,
			_coffin_exile.bind(card.id, card.layer_timestamp),
			"When Coffin Queen becomes untapped or you lose control of it, exile %s." % card.data.card_name,
			_coffin_released.bind(controller, queen_stamp))
		watch.also_when(Mtg.EventType.CONTROL_CHANGED)
		watch.also_when(Mtg.EventType.LEAVES_BATTLEFIELD)
		game.schedule_delayed_trigger(watch, controller, source)

	func describe() -> String:
		return "puts target creature card from a graveyard onto the battlefield under your control"

	static func _coffin_released(_g: MtgGame, s: CardInstance, e: GameEvent, pid: int, stamp: int) -> bool:
		if e.data.get("instance") != s or s.layer_timestamp != stamp:
			return false
		match e.type:
			Mtg.EventType.BECAME_UNTAPPED:
				return true
			Mtg.EventType.CONTROL_CHANGED:
				return int(e.data.get("from_controller", -1)) == pid
			Mtg.EventType.LEAVES_BATTLEFIELD:
				return int(e.data.get("from_controller", pid)) == pid
		return false

	static func _coffin_exile(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var raised := g.find_instance(id)
		if g.is_present(raised) and raised.layer_timestamp == stamp:
			g.exile_permanent(raised)


## Starke of Rath: destroy the target, then hand Starke — the same object
## that was tapped for this — to that permanent's controller, read as the
## ability resolves (before the destruction). The control change happens
## whether or not the destruction did (a regenerated creature); it lasts
## indefinitely (CR 611.2a). A DestroyEffect, so the fair AI reads removal.
class StarkeDestroy extends DestroyEffect:
	func _init(spec: TargetSpec) -> void:
		super(spec)
		# The fair AI's reading (engine/ai/tempest_tactics.gd): removal that
		# hands this creature to the victim's controller.
		ai_role = &"destroy_donates_self"

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value := 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if not game.is_present(victim):
			return
		var heir := victim.controller_id
		super.resolve(game, source, controller, target, x_value)
		if game.is_present(source) \
				and source.layer_timestamp == int(game.cost_paid("_source_timestamp", source.layer_timestamp)) \
				and source.controller_id != heir:
			game.change_control(source, heir)

	func describe() -> String:
		return "destroys target artifact or creature; its controller gains control of Starke"
