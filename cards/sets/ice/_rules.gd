extends RefCounted
## Reviewed Ice Age rules. Metadata lives in each card file; optional ZIPs
## cannot introduce executable behavior. Unreviewed cards are fail-closed
## during development, never silently treated as vanilla permanents.

const F := preload("res://cards/sets/fem/_rules.gd")
const PAIN := {"Adarkar Wastes": [Mtg.ManaColor.W, Mtg.ManaColor.U],
	"Brushland": [Mtg.ManaColor.G, Mtg.ManaColor.W], "Karplusan Forest": [Mtg.ManaColor.R, Mtg.ManaColor.G],
	"Sulfurous Springs": [Mtg.ManaColor.B, Mtg.ManaColor.R], "Underground River": [Mtg.ManaColor.U, Mtg.ManaColor.B]}
const DEPLETION := {"Land Cap": [Mtg.ManaColor.W, Mtg.ManaColor.U], "River Delta": [Mtg.ManaColor.U, Mtg.ManaColor.B],
	"Lava Tubes": [Mtg.ManaColor.B, Mtg.ManaColor.R], "Timberline Ridge": [Mtg.ManaColor.R, Mtg.ManaColor.G],
	"Veldt": [Mtg.ManaColor.G, Mtg.ManaColor.W]}
const VANILLA := ["Balduvian Barbarians", "Balduvian Bears", "Glacial Wall", "Kjeldoran Phalanx",
	"Kjeldoran Skycaptain", "Kjeldoran Skyknight", "Kjeldoran Warrior", "Moor Fiend", "Mountain Goat",
	"Pale Bears", "Pygmy Allosaurus", "Sabretooth Tiger", "Scaled Wurm", "Shield Bearer",
	"Silver Erne", "Tor Giant", "Wall of Shields", "Legions of Lim-Dûl", "Rime Dryad"]
const PUMPS := {"Adarkar Sentinel": ["{1}", 0, 1], "Flame Spirit": ["{R}", 1, 0],
	"Sea Spirit": ["{U}", 1, 0], "Folk of the Pines": ["{1}{G}", 1, 0],
	"Hoar Shade": ["{B}", 1, 1], "Thunder Wall": ["{U}", 1, 1],
	"Wall of Lava": ["{R}", 1, 1], "Shambling Strider": ["{R}{G}", 1, -1]}
const UPKEEP := {"Arnjlot's Ascent": "{U}", "Blizzard": "{2}", "Brand of Ill Omen": "{R}",
	"Breath of Dreams": "{U}", "Cold Snap": "{2}", "Energy Storm": "{1}", "Flow of Maggots": "{1}",
	"Fyndhorn Pollen": "{1}", "Halls of Mist": "{1}", "Illusionary Forces": "{U}",
	"Illusionary Presence": "{U}", "Illusionary Terrain": "{2}", "Illusionary Wall": "{U}",
	"Illusions of Grandeur": "{2}", "Maddening Wind": "{G}", "Mesmeric Trance": "{1}",
	"Musician": "{1}", "Mystic Might": "{1}{U}", "Mystic Remora": "{1}", "Naked Singularity": "{3}",
	"Reality Twist": "{1}{U}{U}", "Ritual of Subdual": "{2}", "Snowfall": "{U}", "Soldevi Simulacrum": "{1}"}

static func apply(c: CardData) -> CardData:
	var name := c.card_name
	if UPKEEP.has(name):
		CumulativeUpkeep.attach(c, UPKEEP[name])
	elif name == "Infernal Darkness":
		CumulativeUpkeep.attach(c, "{B}", 1)
	elif name == "Glacial Chasm":
		CumulativeUpkeep.attach(c, "", 2)
	elif name == "Polar Kraken":
		CumulativeUpkeep.attach(c, "", 0, "land")
	var done: bool = configure(c) or load("res://cards/sets/ice/_more.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_worlds.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_auras_more.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_combat_more.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_library.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_choices.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_patterns.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_storage.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_control.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_remaining.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_reanimation.gd").configure(c)
	if not done: done = load("res://cards/sets/ice/_declarations.gd").configure(c)
	if not done:
		c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid():
			trigger.capturing(F._source_context)
	for ability in c.activated_abilities:
		var extra: Array[String] = []
		if ability.sacrifice_cost: extra.append("Sacrifice this permanent")
		if ability.sacrifice_filter.is_valid(): extra.append("Sacrifice %d %s" % [ability.sacrifice_count, ability.sacrifice_filter_desc])
		if ability.life_cost > 0: extra.append("Pay %d life" % ability.life_cost)
		if ability.counter_cost_kind != "": extra.append("Remove %d %s counter(s)" % [ability.counter_cost_count, ability.counter_cost_kind])
		if ability.discard_cost > 0 or ability.random_discard_cost > 0:
			extra.append("Discard %d card(s)%s" % [maxi(ability.discard_cost, ability.random_discard_cost), " at random" if ability.random_discard_cost > 0 else ""])
		if ability.tap_permanent_count > 0: extra.append("Tap %d eligible permanent(s)" % ability.tap_permanent_count)
		if not extra.is_empty(): ability.text = "; ".join(extra) + " — " + ability.text
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Ice Age rules integration is not yet complete for this card"

static func configure(c: CardData) -> bool:
	var n := c.card_name
	if VANILLA.has(n): return true
	if n.begins_with("Snow-Covered "):
		c.mana(ManaAbility.new(Mtg.BASIC_LAND_COLORS[c.subtypes[0]]))
		return true
	if PAIN.has(n):
		c.mana(ManaAbility.new(Mtg.ManaColor.C))
		for color in PAIN[n]:
			c.mana(ManaAbility.new(color).hurting(1).with_side_effect(_pain))
		return true
	if DEPLETION.has(n):
		for color in DEPLETION[n]:
			c.mana(ManaAbility.new(color).with_side_effect(_deplete))
		c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _remove_depletion,
			"Remove a depletion counter.", F._your_upkeep))
		c.static_ability(StaticAbility.new(_depletion_lock, "Doesn't untap with a depletion counter."))
		return true
	if PUMPS.has(n):
		var row: Array = PUMPS[n]
		c.activated(F._ability(row[0], false, PumpEffect.new(row[1], row[2]).self_buff()))
		return true
	match n:
		"Illusionary Forces", "Illusionary Wall":
			pass
		"Polar Kraken":
			c.with_enters_tapped()
		"Wind Spirit":
			c.static_ability(StaticAbility.new(_menace, "Menace."))
		"Fyndhorn Elves", "Fyndhorn Elder":
			c.mana(ManaAbility.new(Mtg.ManaColor.G, 1 if n == "Fyndhorn Elves" else 2))
		"Adarkar Unicorn":
			c.mana(ManaAbility.new(Mtg.ManaColor.U).with_restriction("cumulative_upkeep"))
			c.mana(ManaAbility.new(Mtg.ManaColor.C).and_also(Mtg.ManaColor.U).with_restriction("cumulative_upkeep"))
		"Yavimaya Gnats", "Wall of Pine Needles":
			c.activated(F._ability("{G}", false, RegenerateEffect.new()))
		"Zuran Spellcaster":
			c.activated(F._ability("", true, DamageEffect.new(1).any_target()))
		"Orcish Cannoneers":
			c.activated(F._ability("", true, load("res://cards/sets/2ed/orcish_artillery.gd").ArtilleryEffect.new()))
		"Centaur Archer":
			c.activated(F._ability("", true, DamageEffect.new(1).target_creature("target creature with flying", _flying)))
		"Storm Spirit":
			c.activated(F._ability("", true, DamageEffect.new(2).target_creature()))
		"Juniper Order Druid":
			c.activated(F._ability("", true, UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land))))
		"Fyndhorn Brownie":
			c.activated(F._ability("{2}{G}", true, UntapEffect.new(TargetSpec.creature())))
		"Knight of Stromgald", "Order of the White Shield":
			var color := "{B}" if n == "Knight of Stromgald" else "{W}"
			c.activated(F._ability(color, false, PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()))
			c.activated(F._ability(color + color, false, PumpEffect.new(1, 0).self_buff()))
		"Kjeldoran Knight":
			c.activated(F._ability("{1}{W}", false, PumpEffect.new(1, 0).self_buff()))
			c.activated(F._ability("{W}{W}", false, PumpEffect.new(0, 2).self_buff()))
		"Hyalopterous Lemure":
			c.activated(F._ability("", false, PumpEffect.new(-1, 0, [Mtg.Keyword.FLYING]).self_buff()))
		"Soldevi Simulacrum":
			c.activated(F._ability("{1}", false, PumpEffect.new(1, 0).self_buff()))
		"Snow Fortress":
			c.activated(F._ability("{1}", false, PumpEffect.new(1, 0).self_buff()))
			c.activated(F._ability("{1}", false, PumpEffect.new(0, 1).self_buff()))
			var ping := DamageEffect.new(1).target_creature("target nonflying creature attacking you")
			ping.target_spec.with_source_filter(_ground_attacking_you)
			c.activated(F._ability("{3}", false, ping))
		"Zuran Orb":
			c.activated(F._ability("", false, GainLifeEffect.new(2)).with_sacrifice_of("land", _land))
		"Sunstone":
			c.activated(F._ability("{2}", false, PreventCombatDamageEffect.new()).with_sacrifice_of("snow land", _snow_land))
		"Glacial Crevasses":
			c.activated(F._ability("", false, PreventCombatDamageEffect.new()).with_sacrifice_of("snow Mountain", _snow_mountain))
		"Skull Catapult":
			c.activated(F._ability("{1}", true, DamageEffect.new(2).any_target()).with_sacrifice_of("creature", _creature))
		"Stormbind":
			c.activated(F._ability("{2}", false, DamageEffect.new(2).any_target()).with_random_discard_cost(1))
		"Mesmeric Trance":
			c.activated(F._ability("{U}", false, DrawEffect.new(1)).with_discard_cost(1))
		"Order of the Sacred Torch", "Stromgald Cabal":
			var color := Mtg.ManaColor.B if n == "Order of the Sacred Torch" else Mtg.ManaColor.W
			c.activated(F._ability("", true, CounterEffect.new("target " + Mtg.COLOR_NAMES[color] + " spell",
				F._color.bind(color))).with_life_cost(1))
		"Zuran Enchanter":
			c.activated(F._ability("{2}{B}", true, Discard.new(1)).your_turn_only())
		"Shield of the Ages":
			c.activated(F._ability("{2}", false, PreventDamageEffect.new(1).to_controller()))
		"Baton of Morale", "War Chariot", "Fyndhorn Bow":
			var keyword: int = {"Baton of Morale": Mtg.Keyword.BANDING, "War Chariot": Mtg.Keyword.TRAMPLE,
				"Fyndhorn Bow": Mtg.Keyword.FIRST_STRIKE}[n]
			c.activated(F._ability("{2}" if n == "Baton of Morale" else "{3}",
				n != "Baton of Morale", PumpEffect.new(0, 0, [keyword])))
		"Whalebone Glider":
			var pump := PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])
			pump.target_spec = TargetSpec.creature("target creature with power 3 or less", _small_power)
			c.activated(F._ability("{2}", true, pump))
		"Kelsinko Ranger":
			var pump := PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE])
			pump.target_spec = TargetSpec.creature("target green creature", F._color.bind(Mtg.ManaColor.G))
			c.activated(F._ability("{1}{W}", false, pump))
		"Aegis of the Meek":
			var pump := PumpEffect.new(1, 2)
			pump.target_spec = TargetSpec.creature("target 1/1 creature", _one_one)
			c.activated(F._ability("{1}", true, pump))
		"Arnjlot's Ascent":
			c.activated(F._ability("{1}", false, PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])))
		"Fanatical Fever":
			c.spell(PumpEffect.new(3, 0, [Mtg.Keyword.TRAMPLE]))
		"Trailblazer":
			c.spell(PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE]))
		"Blessed Wine":
			c.spell(GainLifeEffect.new(1)).spell(DelayedDrawEffect.new())
		"Flare":
			c.spell(DamageEffect.new(1).any_target()).spell(DelayedDrawEffect.new())
		"Enervate":
			var tap := TapEffect.new()
			tap.target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", _acl)
			c.spell(tap).spell(DelayedDrawEffect.new())
		"Infuse":
			c.spell(UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", _acl)))
			c.spell(DelayedDrawEffect.new())
		"Heal":
			c.spell(PreventDamageEffect.new(1).any_target()).spell(DelayedDrawEffect.new())
		"Lightning Blow", "Formation", "Updraft":
			var keyword: int = {"Lightning Blow": Mtg.Keyword.FIRST_STRIKE, "Formation": Mtg.Keyword.BANDING,
				"Updraft": Mtg.Keyword.FLYING}[n]
			c.spell(PumpEffect.new(0, 0, [keyword])).spell(DelayedDrawEffect.new())
		"Force Void":
			c.spell(F.TollCounter.new("{1}")).spell(DelayedDrawEffect.new())
		"Mind Ravel":
			c.spell(Discard.new(1)).spell(DelayedDrawEffect.new())
		"Ray of Erasure":
			c.spell(MillEffect.new(1)).spell(DelayedDrawEffect.new())
		"Touch of Death":
			c.spell(DamageEffect.new(1).target_player()).spell(GainLifeEffect.new(1)).spell(DelayedDrawEffect.new())
		"Pyknite":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _enter_draw,
				"Draw at the beginning of the next turn's upkeep.", F._self_enter))
		"Dark Banishing":
			c.spell(DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack), false))
		"Anarchy":
			c.spell(DestroyAllEffect.new("all white permanents", F._color.bind(Mtg.ManaColor.W)))
		"Jokulhaups":
			c.spell(DestroyAllEffect.new("all artifacts, creatures and lands", _acl, false))
		"Pyroclasm":
			c.spell(DamageAllEffect.new(2))
		"Hymn of Rebirth":
			var revival := ReturnFromGraveyardEffect.new().to_battlefield()
			revival.target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD)
			c.spell(revival)
		"Tarpan":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _tarpan, "Gain 1 life.", F._self_enter))
		_:
			return load("res://cards/sets/ice/_snow.gd").configure(c) or load("res://cards/sets/ice/_auras.gd").configure(c) or load("res://cards/sets/ice/_spells.gd").configure(c) or load("res://cards/sets/ice/_creatures.gd").configure(c) or load("res://cards/sets/ice/_permanents.gd").configure(c)
	return true

static func _land(i: CardInstance) -> bool: return i.is_land()
static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _snow_land(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.SNOW) != 0
static func _snow_mountain(i: CardInstance) -> bool: return _snow_land(i) and i.has_subtype("mountain")
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _acl(i: CardInstance) -> bool: return i.is_land() or i.is_creature() or i.is_type(Mtg.CardType.ARTIFACT)
static func _one_one(i: CardInstance) -> bool: return i.cur_power == 1 and i.cur_toughness == 1
static func _small_power(i: CardInstance) -> bool: return i.cur_power <= 3
static func _ground_attacking_you(g: MtgGame, source: CardInstance, i: CardInstance) -> bool:
	return not _flying(i) and g.combat.attackers.has(i.id) and i.controller_id != source.controller_id
static func _menace(_g: MtgGame, source: CardInstance) -> void: source.cur_min_blockers = maxi(source.cur_min_blockers, 2)
static func _pain(g: MtgGame, source: CardInstance, pid: int) -> void: g.deal_damage(source, TargetRef.player(pid), 1)
static func _deplete(g: MtgGame, source: CardInstance, _pid: int) -> void: g.add_counters(source, "depletion")
static func _depletion_lock(_g: MtgGame, source: CardInstance) -> void:
	if int(source.counters.get("depletion", 0)) > 0: source.cur_skips_untap = true
static func _remove_depletion(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, source): g.remove_counters(source, "depletion")
static func _enter_draw(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	DelayedDrawEffect.new().resolve(g, source, int(g.trigger_context(source).controller), null)
static func _tarpan(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	g.adjust_life(int(g.trigger_context(source).controller), 1)

class Discard extends EffectBase:
	var count: int
	func _init(n: int) -> void:
		count = n
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var choices := g.agents[who].choose_discard(g, who, mini(count, g.players[who].hand.size()))
		g.discard_cards(who, choices)
	func describe() -> String: return "target player discards %d card(s)" % count
