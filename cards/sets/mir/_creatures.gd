extends RefCounted
## Mirage (_creatures, Pack 8). Creatures with activated, static or
## characteristic-defining abilities. Every listed name is complete: each
## clause of its Oracle text is implemented here (or printed on the card
## file — flying, landwalk, protection), with typed effects wherever the
## shared vocabulary has one, so the fair AI reads them (EffectIntent).
## Ability texts are the printed lines, costs included, because this
## dispatcher adds no cost decoration (cards/sets/mir/_rules.gd).
##
## The card-local effect classes below each guard "this creature" against
## a NEW object (CR 400.7) through the activation's own source timestamp
## ([method MtgGame.cost_paid] `_source_timestamp`).
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Civic Guildmage":
			c.activated(_ab("{G}", true, PumpEffect.new(0, 1), "{G}, {T}: Target creature gets +0/+1 until end of turn."))
			c.activated(_ab("{U}", true, LibraryTop.new(), "{U}, {T}: Put target creature you control on top of its owner's library."))
		"Ethereal Champion":
			c.activated(_ab("", false, SelfPrevent.new(), "Pay 1 life: Prevent the next 1 damage that would be dealt to this creature this turn.").with_life_cost(1))
		"Femeref Healer":
			c.activated(_ab("", true, PreventDamageEffect.new(1).any_target(), "{T}: Prevent the next 1 damage that would be dealt to any target this turn."))
		"Mtenda Griffin":
			c.activated(_ab("{W}", true, GriffinRecall.new(), "{W}, {T}: Return this creature to its owner's hand and return target Griffin card from your graveyard to your hand. Activate only during your upkeep.")
				.during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Pearl Dragon":
			c.activated(_ab("{1}{W}", false, PumpEffect.new(0, 1).self_buff(), "{1}{W}: This creature gets +0/+1 until end of turn."))
		"Rashida Scalebane":
			c.activated(_ab("", true, DragonSlayer.new(), "{T}: Destroy target attacking or blocking Dragon. It can't be regenerated. You gain life equal to its power."))
		"Spectral Guardian":
			c.static_ability(StaticAbility.new(_guardian, "As long as this creature is untapped, noncreature artifacts have shroud."))
		"Unyaro Griffin":
			c.activated(_ab("", false, CounterEffect.new("target red instant or sorcery spell", _red_instant_or_sorcery), "Sacrifice this creature: Counter target red instant or sorcery spell.").with_sacrifice_cost())
		"Vigilant Martyr":
			c.activated(_ab("", false, RegenerateEffect.new().target_creature(), "Sacrifice this creature: Regenerate target creature.").with_sacrifice_cost())
			var counter := CounterEffect.new("target spell that targets an enchantment")
			counter.target_spec.with_game_filter(_targets_an_enchantment)
			c.activated(_ab("{W}{W}", true, counter, "{W}{W}, {T}, Sacrifice this creature: Counter target spell that targets an enchantment.").with_sacrifice_cost())
		"Zuberi, Golden Feather":
			c.static_ability(StaticAbility.new(_griffin_lord, "Other Griffin creatures get +1/+1."))
		# ------------------------------------------------------------- blue
		"Azimaet Drake":
			c.activated(_ab("{U}", false, PumpEffect.new(1, 0).self_buff(), "{U}: This creature gets +1/+0 until end of turn. Activate only once each turn.").per_turn(1))
		"Daring Apprentice":
			c.activated(_ab("", true, CounterEffect.new(), "{T}, Sacrifice this creature: Counter target spell.").with_sacrifice_cost())
		"Hakim, Loreweaver":
			c.activated(_ab("{U}{U}", false, AuraRaise.new(), "{U}{U}: Return target Aura card from your graveyard to the battlefield attached to Hakim. Activate only during your upkeep and only if Hakim isn't enchanted.")
				.during_step(Mtg.Step.UPKEEP).your_turn_only().only_if(_unenchanted))
			c.activated(_ab("{U}{U}", true, AuraPurge.new(), "{U}{U}, {T}: Destroy all Auras attached to Hakim."))
		"Harmattan Efreet":
			c.activated(_ab("{1}{U}{U}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]), "{1}{U}{U}: Target creature gains flying until end of turn."))
		"Kukemssa Serpent":
			c.with_attack_needs_defender_land("island").with_sacrifice_if_no_land("island")
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land an opponent controls", _land).with_source_filter(_theirs)
			c.activated(_ab("{U}", false, F.Action.new(_islandify, "target land an opponent controls becomes an Island until end of turn", spec),
				"{U}, Sacrifice an Island: Target land an opponent controls becomes an Island until end of turn.").with_sacrifice_of("Island", _island))
		"Shaper Guildmage":
			c.activated(_ab("{W}", true, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]), "{W}, {T}: Target creature gains first strike until end of turn."))
			c.activated(_ab("{B}", true, PumpEffect.new(1, 0), "{B}, {T}: Target creature gets +1/+0 until end of turn."))
		"Suq'Ata Firewalker":
			c.static_ability(StaticAbility.new(_red_ward, "This creature can't be the target of red spells or abilities from red sources."))
			c.activated(_ab("", true, DamageEffect.new(1).any_target(), "{T}: This creature deals 1 damage to any target."))
		"Wave Elemental":
			var tap := TapEffect.new(TargetSpec.creature("target creature without flying", _not_flying))
			tap.target_min = 0
			tap.target_max = 3
			c.activated(_ab("{U}", true, tap, "{U}, {T}, Sacrifice this creature: Tap up to three target creatures without flying.").with_sacrifice_cost())
		# ------------------------------------------------------------ black
		"Abyssal Hunter":
			c.activated(_ab("{B}", true, HunterStrike.new(), "{B}, {T}: Tap target creature. This creature deals damage equal to its power to that creature."))
		"Barbed-Back Wurm":
			var shrink := PumpEffect.new(-1, -1)
			shrink.target_spec = TargetSpec.creature("target green creature blocking this creature", _green).with_source_filter(_blocking_source)
			c.activated(_ab("{B}", false, shrink, "{B}: Target green creature blocking this creature gets -1/-1 until end of turn."))
		"Blighted Shaman":
			c.activated(_ab("", true, PumpEffect.new(1, 1), "{T}, Sacrifice a Swamp: Target creature gets +1/+1 until end of turn.").with_sacrifice_of("Swamp", _swamp))
			c.activated(_ab("", true, PumpEffect.new(2, 2), "{T}, Sacrifice a creature: Target creature gets +2/+2 until end of turn.").with_sacrifice_of("creature", _creature).may_sacrifice_itself())
		"Breathstealer":
			c.activated(_ab("{B}", false, PumpEffect.new(1, -1).self_buff(), "{B}: This creature gets +1/-1 until end of turn."))
		"Dirtwater Wraith":
			c.activated(_ab("{B}", false, PumpEffect.new(1, 0).self_buff(), "{B}: This creature gets +1/+0 until end of turn."))
		"Fetid Horror":
			c.activated(_ab("{B}", false, PumpEffect.new(1, 1).self_buff(), "{B}: This creature gets +1/+1 until end of turn."))
		"Gravebane Zombie":
			# A replacement (CR 614.1, engine package E7): destroy, sacrifice,
			# lethal damage and 0 toughness all put it on top of its OWNER's
			# library; it never dies (CR 700.4), so no dies trigger. Tokens
			# are not cards and are not replaced.
			c.with_dies_to_library_top()
		"Mire Shade":
			c.activated(_ab("{B}", false, SelfCounter.new("+1/+1"), "{B}, Sacrifice a Swamp: Put a +1/+1 counter on this creature. Activate only as a sorcery.")
				.with_sacrifice_of("Swamp", _swamp).only_if(_sorcery_speed))
		"Restless Dead":
			c.activated(_ab("{B}", false, RegenerateEffect.new(), "{B}: Regenerate this creature."))
		"Sewer Rats":
			c.activated(_ab("{B}", false, PumpEffect.new(1, 0).self_buff(), "{B}, Pay 1 life: This creature gets +1/+0 until end of turn. Activate no more than three times each turn.")
				.with_life_cost(1).per_turn(3))
		"Shadow Guildmage":
			c.activated(_ab("{U}", true, LibraryTop.new(), "{U}, {T}: Put target creature you control on top of its owner's library."))
			c.activated(ActivatedAbility.new("{R}", true, [DamageEffect.new(1).any_target(), DamageEffect.new(1).to_controller()],
				"{R}, {T}: This creature deals 1 damage to any target and 1 damage to you."))
		"Spirit of the Night":
			c.static_ability(StaticAbility.new(_first_strike_attacking, "This creature has first strike as long as it's attacking.").changing_abilities())
		"Tainted Specter":
			c.activated(_ab("{1}{B}{B}", true, Torment.new(), "{1}{B}{B}, {T}: Target player discards a card unless they put a card from their hand on top of their library. If that player discards a card this way, this creature deals 1 damage to each creature and each player. Activate only as a sorcery.")
				.only_if(_sorcery_speed))
		"Urborg Panther":
			var ambush := DestroyEffect.new(TargetSpec.creature("target creature blocking this creature").with_source_filter(_blocking_source))
			c.activated(_ab("{B}", false, ambush, "{B}, Sacrifice this creature: Destroy target creature blocking it.").with_sacrifice_cost())
			var summon := SearchLibraryEffect.new("a card named Spirit of the Night", _named.bind("Spirit of the Night")).to_battlefield()
			var call := _ab("", false, summon, "Sacrifice a creature named Feral Shadow, a creature named Breathstealer, and this creature: Search your library for a card named Spirit of the Night, put that card onto the battlefield, then shuffle.").with_sacrifice_cost()
			call.object_costs = [
				{"operation": "sacrifice", "filter": _named_creature.bind("Feral Shadow"), "desc": "a creature named Feral Shadow"},
				{"operation": "sacrifice", "filter": _named_creature.bind("Breathstealer"), "desc": "a creature named Breathstealer"},
			]
			c.activated(call)
		"Wall of Corpses":
			var ambush := DestroyEffect.new(TargetSpec.creature("target creature this creature is blocking").with_source_filter(_blocked_by_source))
			c.activated(_ab("{B}", false, ambush, "{B}, Sacrifice this creature: Destroy target creature this creature is blocking.").with_sacrifice_cost())
		# -------------------------------------------------------------- red
		"Armorer Guildmage":
			c.activated(_ab("{B}", true, PumpEffect.new(1, 0), "{B}, {T}: Target creature gets +1/+0 until end of turn."))
			c.activated(_ab("{G}", true, PumpEffect.new(0, 1), "{G}, {T}: Target creature gets +0/+1 until end of turn."))
		"Burning Palm Efreet":
			c.activated(_ab("{1}{R}{R}", false, Grounding.new(), "{1}{R}{R}: This creature deals 2 damage to target creature with flying and that creature loses flying until end of turn."))
		"Crimson Hellkite":
			c.activated(_ab("{X}", true, DamageEffect.new(0).target_creature().x_damage(), "{X}, {T}: This creature deals X damage to target creature. Spend only red mana on X.")
				.with_colored_x(Mtg.ManaColor.R))
		"Dwarven Miner":
			c.activated(_ab("{2}{R}", true, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonbasic land", _nonbasic_land)), "{2}{R}, {T}: Destroy target nonbasic land."))
		"Dwarven Nomad":
			var sneak := PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])
			sneak.target_spec = TargetSpec.creature("target creature with power 2 or less", _small)
			c.activated(_ab("", true, sneak, "{T}: Target creature with power 2 or less can't be blocked this turn."))
		"Flame Elemental":
			c.activated(_ab("{R}", true, LastBlast.new(), "{R}, {T}, Sacrifice this creature: It deals damage equal to its power to target creature.").with_sacrifice_cost())
		"Goblin Soothsayer":
			c.activated(_ab("{R}", true, MassPumpEffect.new(1, 1, "red creatures").with_filter(_red), "{R}, {T}, Sacrifice a Goblin: Red creatures get +1/+1 until end of turn.")
				.with_sacrifice_of("Goblin", _goblin).may_sacrifice_itself())
		"Goblin Tinkerer":
			c.activated(_ab("{R}", true, Tinker.new(), "{R}, {T}: Destroy target artifact. That artifact deals damage equal to its mana value to this creature."))
		"Hivis of the Scale":
			c.with_may_skip_untap()
			c.activated(_ab("", true, F.Action.new(F._seasinger, "gain control of target Dragon for as long as you control Hivis and Hivis remains tapped",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Dragon", _dragon)), "{T}: Gain control of target Dragon for as long as you control Hivis and Hivis remains tapped."))
		"Pyric Salamander":
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff(), SelfDoom.new()],
				"{R}: This creature gets +1/+0 until end of turn. Sacrifice this creature at the beginning of the next end step."))
		"Raging Spirit":
			c.activated(_ab("{2}", false, SelfColorless.new(), "{2}: This creature becomes colorless until end of turn."))
		"Reckless Embermage":
			c.activated(_ab("{1}{R}", false, Backfire.new(), "{1}{R}: This creature deals 1 damage to any target and 1 damage to itself."))
		"Subterranean Spirit":
			c.activated(_ab("", true, DamageAllEffect.new(1, "each creature without flying", _not_flying), "{T}: This creature deals 1 damage to each creature without flying."))
		"Wildfire Emissary":
			c.activated(_ab("{1}{R}", false, PumpEffect.new(1, 0).self_buff(), "{1}{R}: This creature gets +1/+0 until end of turn."))
		"Zirilan of the Claw":
			c.activated(_ab("{1}{R}{R}", true, DragonCall.new(), "{1}{R}{R}, {T}: Search your library for a Dragon permanent card, put that card onto the battlefield, then shuffle. That Dragon gains haste until end of turn. Exile it at the beginning of the next end step."))
		# ------------------------------------------------------------ green
		"Canopy Dragon":
			c.activated(ActivatedAbility.new("{1}{G}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff(), SelfLoss.new([Mtg.Keyword.TRAMPLE], "trample")],
				"{1}{G}: This creature gains flying and loses trample until end of turn."))
		"Femeref Archers":
			var shot := DamageEffect.new(4).target_creature("target attacking creature with flying", _flying)
			shot.target_spec.with_game_filter(_attacking)
			c.activated(_ab("", true, shot, "{T}: This creature deals 4 damage to target attacking creature with flying."))
		"Foratog":
			c.activated(_ab("{G}", false, PumpEffect.new(2, 2).self_buff(), "{G}, Sacrifice a Forest: This creature gets +2/+2 until end of turn.").with_sacrifice_of("Forest", _forest))
		"Granger Guildmage":
			c.activated(ActivatedAbility.new("{R}", true, [DamageEffect.new(1).any_target(), DamageEffect.new(1).to_controller()],
				"{R}, {T}: This creature deals 1 damage to any target and 1 damage to you."))
			c.activated(_ab("{W}", true, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]), "{W}, {T}: Target creature gains first strike until end of turn."))
		"Jungle Patrol":
			var wood := CreateTokenEffect.new("Wood", 0, 1, Mtg.ManaColor.G, "wall")
			wood.token.with_keywords([Mtg.Keyword.DEFENDER])
			wood.token.oracle("Defender")
			c.activated(_ab("{1}{G}", true, wood, "{1}{G}, {T}: Create a 0/1 green Wall creature token with defender named Wood."))
			c.mana(ManaAbility.new(Mtg.ManaColor.R).without_tap().with_sacrifice_of("token named Wood", _wood))
		"Locust Swarm":
			c.activated(_ab("{G}", false, RegenerateEffect.new(), "{G}: Regenerate this creature."))
			c.activated(_ab("{G}", false, SelfUntap.new(), "{G}: Untap this creature. Activate only once each turn.").per_turn(1))
		"Maro":
			c.static_ability(StaticAbility.new(_hand_size, "Power and toughness are each equal to the number of cards in your hand.").setting_base_pt())
			c.characteristic_definition = _hand_size
		"Uktabi Faerie":
			c.activated(_ab("{3}{G}", false, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact)), "{3}{G}, Sacrifice this creature: Destroy target artifact.").with_sacrifice_cost())
		"Uktabi Wildcats":
			c.static_ability(StaticAbility.new(_forest_count, "Power and toughness are each equal to the number of Forests you control.").setting_base_pt())
			c.characteristic_definition = _forest_count
			c.activated(_ab("{G}", false, RegenerateEffect.new(), "{G}, Sacrifice a Forest: Regenerate this creature.").with_sacrifice_of("Forest", _forest))
		"Unseen Walker":
			c.activated(_ab("{1}{G}{G}", false, GrantLandwalkEffect.new(["forest"]), "{1}{G}{G}: Target creature gains forestwalk until end of turn."))
		"Village Elder":
			c.activated(_ab("{G}", true, RegenerateEffect.new().target_creature(), "{G}, {T}, Sacrifice a Forest: Regenerate target creature.").with_sacrifice_of("Forest", _forest))
		# ------------------------------------------------------------- gold
		"Haunting Apparition":
			c.as_it_enters(_choose_opponent)
			c.static_ability(StaticAbility.new(_haunting, "Power is equal to 1 plus the number of green creature cards in the chosen player's graveyard.").setting_base_pt())
		"Jungle Troll":
			c.activated(_ab("{R}", false, RegenerateEffect.new(), "{R}: Regenerate this creature."))
			c.activated(_ab("{G}", false, RegenerateEffect.new(), "{G}: Regenerate this creature."))
		"Leering Gargoyle":
			c.activated(ActivatedAbility.new("", true, [PumpEffect.new(-2, 2).self_buff(), SelfLoss.new([Mtg.Keyword.FLYING], "flying")],
				"{T}: This creature gets -2/+2 and loses flying until end of turn."))
		"Radiant Essence":
			c.static_ability(StaticAbility.new(_radiant, "This creature gets +1/+2 as long as an opponent controls a black permanent."))
		"Sawback Manticore":
			c.activated(_ab("{4}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff(), "{4}: This creature gains flying until end of turn."))
			var shot := DamageEffect.new(2).target_creature("target attacking or blocking creature")
			shot.target_spec.with_game_filter(_in_combat)
			c.activated(_ab("{1}", false, shot,
				"{1}: This creature deals 2 damage to target attacking or blocking creature. Activate only if this creature is attacking or blocking and only once each turn.")
				.only_if(_source_in_combat).per_turn(1))
		"Shauku's Minion":
			c.activated(_ab("{B}{R}", true, DamageEffect.new(2).target_creature("target white creature", _white), "{B}{R}, {T}: This creature deals 2 damage to target white creature."))
		# -------------------------------------------------------- artifacts
		"Ersatz Gnomes":
			c.activated(_ab("", true, ChangeColorEffect.new(0, TargetSpec.spell()), "{T}: Target spell becomes colorless."))
			c.activated(_ab("", true, ChangeColorEffect.new(0, TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent")).until_end_of_turn(), "{T}: Target permanent becomes colorless until end of turn."))
		"Igneous Golem":
			c.activated(_ab("{2}", false, PumpEffect.new(0, 0, [Mtg.Keyword.TRAMPLE]).self_buff(), "{2}: This creature gains trample until end of turn."))
		"Patagia Golem":
			c.activated(_ab("{3}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff(), "{3}: This creature gains flying until end of turn."))
		_: return false
	return true


static func _ab(cost: String, taps: bool, effect: EffectBase, text: String) -> ActivatedAbility:
	return ActivatedAbility.new(cost, taps, [effect], text)

## The activation's own source is still the object that paid for it.
static func live(g: MtgGame, s: CardInstance) -> bool:
	return F._same_activation_source(g, s)

# -------------------------------------------------------------- predicates
static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _island(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("island")
static func _swamp(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("swamp")
static func _forest(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("forest")
static func _goblin(i: CardInstance) -> bool: return i.is_creature() and i.has_subtype("goblin")
static func _dragon(i: CardInstance) -> bool: return i.has_subtype("dragon")
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _not_flying(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)
static func _small(i: CardInstance) -> bool: return i.cur_power <= 2
static func _red(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.R)
static func _green(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.G)
static func _white(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.W)
static func _nonbasic_land(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0
static func _wood(i: CardInstance) -> bool: return i.is_token and i.data.card_name == "Wood"
static func _named(i: CardInstance, card_name: String) -> bool: return i.data.card_name == card_name
static func _named_creature(i: CardInstance, card_name: String) -> bool: return i.is_creature() and i.data.card_name == card_name
static func _red_instant_or_sorcery(i: CardInstance) -> bool:
	return i.has_color(Mtg.ManaColor.R) and (i.is_type(Mtg.CardType.INSTANT) or i.is_type(Mtg.CardType.SORCERY))
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _in_combat(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id) or g.combat.blocks.has(i.id)
static func _own(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id == g.controller_acting_for(s)
static func _theirs(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id != g.controller_acting_for(s)
## "Blocking it": blocking any member of the source's band (CR 702.22h) —
## combat records outlive a sacrificed source, so the target stays legal
## on resolution (the Tinder Wall shape, cards/sets/ice/_creatures.gd).
static func _blocking_source(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return g.combat.blockers_of_band(g.combat.band_of(s.id)).has(i.id)
static func _blocked_by_source(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return g.combat.opposing_attackers(s.id).has(i.id)
static func _source_in_combat(g: MtgGame, s: CardInstance) -> String:
	return "" if _in_combat(g, s) else "activate only if this creature is attacking or blocking"
static func _sorcery_speed(g: MtgGame, s: CardInstance) -> String:
	if g.active_player != s.controller_id or not Mtg.is_main_step(g.current_step()) or not g.stack.is_empty():
		return "activate only as a sorcery"
	return ""
static func _unenchanted(g: MtgGame, s: CardInstance) -> String:
	for id in s.attachments:
		var aura := g.find_instance(id)
		if aura != null and aura.zone == Mtg.Zone.BATTLEFIELD and aura.is_aura():
			return "activate only if Hakim isn't enchanted"
	return ""
## "Counter target spell that targets an enchantment": one of the spell's
## own targets is an enchantment on the battlefield (CR 109.2 — an
## unqualified type names a permanent), read from its stack item.
static func _targets_an_enchantment(g: MtgGame, spell: CardInstance) -> bool:
	var item := g.find_stack_item(spell)
	if item == null: return false
	for ref in item.targets:
		if ref == null or ref.is_player: continue
		var aimed := g.find_instance(ref.instance_id)
		if aimed != null and aimed.zone == Mtg.Zone.BATTLEFIELD and aimed.is_type(Mtg.CardType.ENCHANTMENT): return true
	return false

# ----------------------------------------------------------------- statics
static func _guardian(g: MtgGame, s: CardInstance) -> void:
	if s.tapped: return
	for i in g.all_battlefield():
		if i.is_type(Mtg.CardType.ARTIFACT) and not i.is_creature(): i.cur_shroud = true
static func _griffin_lord(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i != s and i.is_creature() and i.has_subtype("griffin"):
			i.cur_power += 1
			i.cur_toughness += 1
static func _red_ward(_g: MtgGame, s: CardInstance) -> void:
	s.cur_target_bans.append({"desc": "red spells or abilities from red sources", "filter": _red_source})
static func _red_source(_g: MtgGame, source: CardInstance, _spec: TargetSpec) -> bool:
	return source != null and source.has_color(Mtg.ManaColor.R)
static func _first_strike_attacking(g: MtgGame, s: CardInstance) -> void:
	if g.combat.attackers.has(s.id) and not s.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
		s.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)
static func _radiant(g: MtgGame, s: CardInstance) -> void:
	for p in g.players:
		if p.id == s.controller_id: continue
		for i in p.battlefield:
			if i.has_color(Mtg.ManaColor.B):
				s.cur_power += 1
				s.cur_toughness += 2
				return
## "You" off the battlefield is the card's owner (CR 604.3, 611.3a: a
## characteristic-defining ability works in every zone).
static func _you(g: MtgGame, s: CardInstance) -> MtgPlayer:
	return g.players[s.controller_id if s.zone == Mtg.Zone.BATTLEFIELD or s.zone == Mtg.Zone.STACK else s.owner_id]
static func _hand_size(g: MtgGame, s: CardInstance) -> void:
	var n := _you(g, s).hand.size()
	s.cur_power = n
	s.cur_toughness = n
static func _forest_count(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in _you(g, s).battlefield:
		if _forest(i): n += 1
	s.cur_power = n
	s.cur_toughness = n
static func _choose_opponent(g: MtgGame, s: CardInstance, pid: int) -> void:
	s.memory["chosen_player"] = g.choose_opponent(pid, s)
static func _haunting(g: MtgGame, s: CardInstance) -> void:
	var who := int(s.memory.get("chosen_player", g.opponent_of(s.controller_id)))
	var n := 0
	for i in g.players[who].graveyard:
		if i.is_creature() and i.has_color(Mtg.ManaColor.G): n += 1
	s.cur_power = 1 + n

# ----------------------------------------------------------------- actions
## Kukemssa Serpent: the land becomes an Island — it loses its other land
## types and their mana abilities (CR 305.7), as Jinx's land does
## (cards/sets/hml/_spells.gd), for the rest of the turn.
static func _islandify(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_become_island.bind(t.instance_id), "Target land becomes an Island.").changing_land_types(),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, t.instance_id)
	g.recalculate()
static func _become_island(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD: i.become_basic_land_type("island", Mtg.BASIC_LAND_COLORS["island"])


# ======================================================== effect classes ==

## "Put target creature you control on top of its owner's library."
class LibraryTop extends ReturnToHandEffect:
	func _init() -> void:
		super(TargetSpec.creature("target creature you control").with_source_filter(_yours))
	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id == g.controller_acting_for(s)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null: g.return_permanent_to_library_top(i)
	func describe() -> String: return "put target creature you control on top of its owner's library"


## "Prevent the next 1 damage that would be dealt to this creature this turn."
class SelfPrevent extends PreventDamageEffect:
	func _init() -> void:
		super(1)
		to_source()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if F._same_activation_source(g, s): super(g, s, pid, t, x)
	func describe() -> String: return "prevent the next 1 damage that would be dealt to this creature this turn"


## Mtenda Griffin: the creature goes home and the Griffin card comes back.
class GriffinRecall extends ReturnFromGraveyardEffect:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, "target Griffin card in your graveyard", _griffin_card)
		ai_helpful = true
	static func _griffin_card(i: CardInstance) -> bool: return i.has_subtype("griffin")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var card := g.find_instance(t.instance_id)
		if F._same_activation_source(g, s): g.return_to_hand(s)
		if card != null and card.zone == Mtg.Zone.GRAVEYARD: g.return_from_graveyard_to_hand(card)
	func describe() -> String: return "return this creature to its owner's hand and target Griffin card from your graveyard to your hand"


## Rashida Scalebane: no regeneration; life equal to the Dragon's power as
## it last existed on the battlefield (CR 608.2h).
class DragonSlayer extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target attacking or blocking Dragon", _dragon_card).with_game_filter(_fighting), false)
	static func _dragon_card(i: CardInstance) -> bool: return i.has_subtype("dragon")
	static func _fighting(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id) or g.combat.blocks.has(i.id)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null: return
		var power := i.cur_power
		g.destroy(i, false)
		if power > 0: g.adjust_life(pid, power)
	func describe() -> String: return "destroy target attacking or blocking Dragon (no regeneration); you gain life equal to its power"


## Hakim: the Aura enters attached to Hakim. One that could not legally
## enchant him stays in the graveyard (CR 303.4g), as does every Aura when
## Hakim has left (a new Hakim is a new object, CR 400.7).
class AuraRaise extends ReturnFromGraveyardEffect:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, "target Aura card in your graveyard", _aura_card)
		ai_helpful = true
	static func _aura_card(i: CardInstance) -> bool: return i.data.is_aura()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var aura := g.find_instance(t.instance_id)
		if aura == null or aura.zone != Mtg.Zone.GRAVEYARD or not F._same_activation_source(g, s): return
		if not g.aura_can_enchant(aura, s): return
		g.attach_aura_from_anywhere(aura, s, pid)
	func describe() -> String: return "return target Aura card from your graveyard to the battlefield attached to Hakim"


## Hakim: "Destroy all Auras attached to Hakim." One simultaneous event.
class AuraPurge extends EffectBase:
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if not F._same_activation_source(g, s): return
		var victims: Array[CardInstance] = []
		for id in s.attachments:
			var aura := g.find_instance(id)
			if aura != null and aura.zone == Mtg.Zone.BATTLEFIELD and aura.is_aura(): victims.append(aura)
		g.begin_simultaneous()
		for aura in victims: g.destroy(aura)
		g.end_simultaneous()
	func describe() -> String: return "destroy all Auras attached to Hakim"


## Abyssal Hunter: tap, then damage equal to the Hunter's power — its last
## known power if it has left (CR 608.2h). The printed 1 is what the AI
## reads; the live power is what is dealt.
class HunterStrike extends DamageEffect:
	func _init() -> void:
		super(1)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null: return
		g.tap_permanent(i)
		var power := s.cur_power if F._same_activation_source(g, s) else s.last_power
		if power > 0: g.deal_damage(s, t, power)
	func describe() -> String: return "tap target creature; this creature deals damage equal to its power to it"


## Mire Shade: "Put a +1/+1 counter on this creature."
class SelfCounter extends CounterMarkerEffect:
	func _init(kind: String) -> void:
		super(kind)
		target_spec = null
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s): g.add_counters(s, kind, count)
	func describe() -> String: return "put a %s counter on this creature" % kind


## Tainted Specter. The TARGET player chooses: put a card from their hand on
## top of their library, or discard. Only a discard deals the 1 damage to
## each creature and each player; an empty hand does neither.
class Torment extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var hand := g.players[who].hand
		if hand.is_empty(): return
		var labels: Array[String] = ["Put a card from your hand on top of your library", "Discard a card"]
		var pick := g.agents[who].choose_option(g, who, labels, "Tainted Specter: put a card on top of your library, or discard a card?", 0)
		if pick == 0:
			var cards: Array[CardInstance] = hand.duplicate()
			var card := g.agents[who].choose_card(g, who, cards, "Tainted Specter: put a card from your hand on top of your library", false)
			if card == null or not hand.has(card): card = cards[0]
			g.put_from_hand_on_top_of_library(card)
			return
		var picked := g.agents[who].choose_discard(g, who, 1)
		var thrown: Array[CardInstance] = [hand[0]]
		if picked.size() == 1 and hand.has(picked[0]): thrown[0] = picked[0]
		g.discard_cards(who, thrown)
		DamageAllEffect.new(1).and_each_player().resolve(g, s, pid, null)
	func describe() -> String:
		return "target player discards a card unless they put a card from their hand on top of their library; a discard deals 1 damage to each creature and each player"


## Burning Palm Efreet: 2 damage and "loses flying until end of turn" on
## the one target — whether or not the damage was prevented.
class Grounding extends DamageEffect:
	func _init() -> void:
		super(2)
		target_creature("target creature with flying", _flier)
	static func _flier(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var lost: Array[int] = [Mtg.Keyword.FLYING]
		g.continuous.add_until_eot_loss(i.id, lost)
		g.recalculate()
	func describe() -> String: return "deals 2 damage to target creature with flying and it loses flying until end of turn"


## Flame Elemental: sacrificed as the cost, so "its power" is the power it
## had as it left (CR 608.2h). The printed 3 is what the AI reads.
class LastBlast extends DamageEffect:
	func _init() -> void:
		super(3)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var power := s.cur_power if s.zone == Mtg.Zone.BATTLEFIELD else s.last_power
		if power > 0: g.deal_damage(s, t, power)
	func describe() -> String: return "deals damage equal to its power to target creature"


## Goblin Tinkerer: destroy the artifact; that artifact (wherever it now is)
## deals damage equal to its mana value to the Tinkerer, if the Tinkerer is
## still the object that activated.
class Tinker extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact_permanent))
	static func _artifact_permanent(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null: return
		var value := i.data.cost.mana_value()
		g.destroy(i)
		if value > 0 and F._same_activation_source(g, s): g.deal_damage(i, TargetRef.card(s), value)
	func describe() -> String: return "destroy target artifact; it deals damage equal to its mana value to this creature"


## Pyric Salamander: "Sacrifice this creature at the beginning of the next
## end step" — the end-step doom, as a sacrifice (CR 701.17).
class SelfDoom extends EffectBase:
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s): g.doom_at_next_end_step(s, false, false, true)
	func describe() -> String: return "sacrifice this creature at the beginning of the next end step"


## Raging Spirit: "This creature becomes colorless until end of turn."
class SelfColorless extends ChangeColorEffect:
	func _init() -> void:
		super(0)
		target_spec = null
		until_eot = true
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if not F._same_activation_source(g, s): return
		g.continuous.add_until_eot_color(s.id, 0)
		g.recalculate()
		g.check_state_based_actions()
	func describe() -> String: return "this creature becomes colorless until end of turn"


## Reckless Embermage: 1 to the target and 1 to itself, one event; the
## self-damage needs the Embermage still on the battlefield.
class Backfire extends DamageEffect:
	func _init() -> void:
		super(1)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.begin_simultaneous()
		g.deal_damage(s, t, 1)
		if F._same_activation_source(g, s): g.deal_damage(s, TargetRef.card(s), 1)
		g.end_simultaneous()
	func describe() -> String: return "deals 1 damage to any target and 1 damage to itself"


## Zirilan of the Claw: the found Dragon permanent card enters, gains haste
## until end of turn, and a delayed trigger exiles THAT object at the next
## end step (CR 603.7; a new object after a zone change is safe, CR 400.7).
class DragonCall extends SearchLibraryEffect:
	func _init() -> void:
		super("a Dragon permanent card", _dragon_permanent)
		battlefield = true
	static func _dragon_permanent(i: CardInstance) -> bool: return i.has_subtype("dragon") and i.data.is_permanent_type()
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var found := g.pick_from_library(pid, filter, "Search your library for a Dragon permanent card")
		if found == null: return
		g.put_into_play(found, pid)
		if found.zone != Mtg.Zone.BATTLEFIELD: return
		var haste: Array[int] = [Mtg.Keyword.HASTE]
		g.continuous.add_until_eot_keywords(found.id, haste)
		g.recalculate()
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
			_exile_it.bind(found.id, found.layer_timestamp), "Exile the Dragon Zirilan of the Claw found."), pid, s)
	static func _exile_it(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var i := g.find_instance(id)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.exile_permanent(i)
	func describe() -> String:
		return "search your library for a Dragon permanent card and put it onto the battlefield; it gains haste and is exiled at the next end step"


## "... loses <keyword> until end of turn" on the ability's own source.
class SelfLoss extends LoseAbilityEffect:
	func _init(lost: Array, what_text: String) -> void:
		super(lost, what_text)
		to_source()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if F._same_activation_source(g, s): super(g, s, pid, t, x)


## Locust Swarm: "Untap this creature."
class SelfUntap extends UntapEffect:
	func _init() -> void:
		target_spec = null
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s): g.untap_permanent(s)
	func describe() -> String: return "untap this creature"
