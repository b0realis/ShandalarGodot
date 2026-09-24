extends RefCounted
## Typed effects retain the shared target picker, deterministic rules and
## fair AI's existing semantic evaluation.

const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bee Sting": c.spell(DamageEffect.new(2).any_target())
		"Blaze": c.spell(DamageEffect.new(0).any_target().x_damage())
		"Scorching Spear": c.spell(DamageEffect.new(1).any_target())
		"Volcanic Hammer": c.spell(DamageEffect.new(3).any_target())
		"Lava Axe": c.spell(DamageEffect.new(5).target_player())
		"Vampiric Feast": c.spell(DamageEffect.new(4).any_target()).spell(GainLifeEffect.new(4))
		"Vampiric Touch":
			var e := DamageEffect.new(2)
			e.target_spec = TargetSpec.opponent()
			c.spell(e).spell(GainLifeEffect.new(2))
		"Soul Shred": c.spell(DamageEffect.new(3).target_creature("target nonblack creature", _nonblack)).spell(GainLifeEffect.new(3))
		"Fire Tempest": c.spell(DamageAllEffect.new(6).and_each_player())
		"Needle Storm": c.spell(DamageAllEffect.new(4, "each creature with flying", _flying))
		"Scorching Winds":
			c.castable_only_when(_attacked)
			c.spell(F.Action.new(_scorch, "deal 1 damage to each attacking creature").with_ai_role(&"damage_sweep", {"amount": 1}))
		"Forked Lightning":
			var e := DamageEffect.new(4).target_creature().divided_among(4)
			e.target_max = 3
			c.spell(e)
		"Hand of Death": c.spell(DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack)))
		"Vengeance": c.spell(DestroyEffect.new(TargetSpec.creature("target tapped creature", _tapped)))
		"Lava Flow": c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target creature or land", _creature_land)))
		"Rain of Tears", "Winter's Grasp": c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)))
		"Rain of Salt":
			var e := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))
			e.target_min = 2
			e.target_max = 2
			c.spell(e)
		"Wicked Pact":
			var e := DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack))
			e.target_min = 2
			e.target_max = 2
			c.spell(e).spell(GainLifeEffect.new(-5))
		"Assassin's Blade":
			c.castable_only_when(_attacked)
			c.spell(DestroyEffect.new(TargetSpec.creature("target nonblack attacking creature", _nonblack).with_game_filter(_attacking)))
		"Nature's Ruin": c.spell(DestroyAllEffect.new("all green creatures", _colored_creature.bind(Mtg.ManaColor.G)))
		"Virtue's Ruin": c.spell(DestroyAllEffect.new("all white creatures", _colored_creature.bind(Mtg.ManaColor.W)))
		"Boiling Seas": c.spell(DestroyAllEffect.new("all Islands", _subtype.bind("island")))
		"Devastation": c.spell(DestroyAllEffect.new("all creatures and lands", _creature_land))
		"Angelic Blessing": c.spell(PumpEffect.new(3, 3, [Mtg.Keyword.FLYING]))
		"Monstrous Growth": c.spell(PumpEffect.new(4, 4))
		"Howling Fury": c.spell(PumpEffect.new(4, 0))
		"Cloak of Feathers": c.spell(PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])).spell(DrawEffect.new(1))
		"Steadfastness": c.spell(MassPumpEffect.new(0, 3, "creatures you control").yours_only())
		"Warrior's Charge": c.spell(MassPumpEffect.new(1, 1, "creatures you control").yours_only())
		"Valorous Charge": c.spell(MassPumpEffect.new(2, 0, "white creatures").with_filter(_colored_creature.bind(Mtg.ManaColor.W)))
		"Treetop Defense":
			c.castable_only_when(_attacked)
			c.spell(MassPumpEffect.new(0, 0, "creatures you control", [Mtg.Keyword.REACH]).yours_only())
		"Touch of Brilliance": c.spell(DrawEffect.new(2))
		"Sacred Nectar": c.spell(GainLifeEffect.new(4))
		"Natural Spring": c.spell(GainLifeEffect.new(8).target_player())
		"Breath of Life": c.spell(ReturnFromGraveyardEffect.new().to_battlefield())
		"Elven Cache": c.spell(ReturnFromGraveyardEffect.new().any_card())
		"Déjà Vu":
			var e := ReturnFromGraveyardEffect.new().any_card()
			e.target_spec.filter = _sorcery
			c.spell(e)
		"Mystic Denial": c.spell(CounterEffect.new("target creature or sorcery spell", _creature_sorcery))
		"Symbol of Unsummoning": c.spell(ReturnToHandEffect.new()).spell(DrawEffect.new(1))
		"Command of Unsummoning":
			c.castable_only_when(_attacked)
			var e := ReturnToHandEffect.new(TargetSpec.creature("target attacking creature").with_game_filter(_attacking))
			e.target_max = 2
			c.spell(e)
		"Tidal Surge":
			var e := TapEffect.new(TargetSpec.creature("target creature without flying", _not_flying))
			e.target_min = 0
			e.target_max = 3
			c.spell(e)
		"Mind Knives":
			var e := RandomHandDiscardEffect.new(1)
			e.target_spec = TargetSpec.opponent()
			c.spell(e)
		"Natural Order":
			c.with_additional_sacrifice("green creature", _colored_creature.bind(Mtg.ManaColor.G))
			c.spell(SearchLibraryEffect.new("a green creature card", _colored_creature.bind(Mtg.ManaColor.G)).to_battlefield())
		"Craven Giant", "Craven Knight", "Hulking Cyclops", "Hulking Goblin", "Jungle Lion":
			c.static_ability(StaticAbility.new(_no_block, "This creature can't block."))
		"Cloud Dragon", "Cloud Pirates", "Cloud Spirit":
			c.static_ability(StaticAbility.new(_flying_block, "This creature can block only creatures with flying."))
		"Deep-Sea Serpent": c.with_attack_needs_defender_land("island")
		"Fleet-Footed Monk": c.with_cant_be_blocked_by_power_ge(2)
		"Phantom Warrior": c.static_ability(StaticAbility.new(_unblockable, "This creature can't be blocked."))
		"Sacred Knight": c.static_ability(StaticAbility.new(_sacred, "This creature can't be blocked by black or red creatures."))
		"Capricious Sorcerer": c.activated(F._ability("", true, DamageEffect.new(1).any_target()).your_turn_only().before_step(Mtg.Step.DECLARE_ATTACKERS))
		"King's Assassin": c.activated(F._ability("", true, DestroyEffect.new(TargetSpec.creature("target tapped creature", _tapped))).your_turn_only().before_step(Mtg.Step.DECLARE_ATTACKERS))
		"Stern Marshal": c.activated(F._ability("", true, PumpEffect.new(2, 2)).your_turn_only().before_step(Mtg.Step.DECLARE_ATTACKERS))
		_: return false
	return true

static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _tapped(i: CardInstance) -> bool: return i.tapped
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _not_flying(i: CardInstance) -> bool: return not _flying(i)
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _creature_land(i: CardInstance) -> bool: return i.is_creature() or i.is_land()
static func _sorcery(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.SORCERY)
static func _creature_sorcery(i: CardInstance) -> bool: return i.is_creature() or _sorcery(i)
static func _colored_creature(i: CardInstance, color: int) -> bool: return i.is_creature() and (i.cur_colors & color) != 0
static func _subtype(i: CardInstance, subtype: String) -> bool: return i.has_subtype(subtype)
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _attacked(g: MtgGame, pid: int) -> String:
	if g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.active_player == pid or g.awaiting_attackers:
		return "Cast only after you have been attacked, during declare attackers"
	return "" if g.players[g.active_player].attacked_this_turn else "You have not been attacked this step"
static func _no_block(_g: MtgGame, s: CardInstance) -> void: s.cur_cant_block_filter = _anything
static func _anything(_i: CardInstance) -> bool: return true
static func _nothing(_i: CardInstance) -> bool: return false
static func _flying_block(_g: MtgGame, s: CardInstance) -> void: s.cur_cant_block_filter = _not_flying
static func _unblockable(_g: MtgGame, s: CardInstance) -> void: s.cur_block_restrictions.append({"desc": "can't be blocked", "filter": _nothing})
static func _not_black_red(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.B | Mtg.ManaColor.R)) == 0
static func _sacred(_g: MtgGame, s: CardInstance) -> void: s.cur_block_restrictions.append({"desc": "nonblack, nonred creatures", "filter": _not_black_red})
static func _scorch(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	g.begin_simultaneous()
	for id in g.combat.attackers:
		var i := g.find_instance(id)
		if i != null and i.is_creature(): g.deal_damage(s, TargetRef.card(i), 1)
	g.end_simultaneous()
