extends RefCounted
## Tempest (_costs, Pack 9). Additional and alternative costs, upkeep costs and cost modifiers.
##
## Costs are the engine's own vocabulary: additional object costs
## (engine/additional_object_costs.gd — "discard X cards", "discard X land
## cards", "sacrifice a creature"), activation costs, cost modifiers
## (CardData.with_cost_modifier: the Medallions' "spells YOU cast" is read
## off the modifier's own source, Chill taxes every caster), and the
## permissions engine package E2 added: an alternative cost a permanent
## GRANTS (Aluren), static flash (Rootwater Shaman) and the spells-cast
## count (Skyshroud Condor). Every cost is validated before anything
## moves and paid as the spell or ability goes on the stack (CR 601.2h,
## 602.2b); a static artifact stops while tapped under the 1997 rules
## (RulesOptions.tapped_artifacts_stop, MtgGame.cost_modifier_works).
## Tests: tests/cards/test_pack_9_B2_costs_tmp.gd.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- artifact
		"Emerald Medallion": c.with_cost_modifier(_green_medallion)
		"Jet Medallion": c.with_cost_modifier(_black_medallion)
		"Pearl Medallion": c.with_cost_modifier(_white_medallion)
		"Ruby Medallion": c.with_cost_modifier(_red_medallion)
		"Sapphire Medallion": c.with_cost_modifier(_blue_medallion)
		# ------------------------------------------------------------ white
		"Pegasus Refuge":
			var pegasus := CreateTokenEffect.new("Pegasus", 1, 1, Mtg.ManaColor.W, "pegasus")
			pegasus.token.with_keywords([Mtg.Keyword.FLYING])
			c.activated(ActivatedAbility.new("{2}", false, [pegasus],
				"{2}, Discard a card: Create a 1/1 white Pegasus creature token with flying.").with_discard_cost(1))
		# ------------------------------------------------------------- blue
		"Chill": c.with_cost_modifier(_chill)
		"Rootwater Shaman": c.with_granted_flash(_shaman_flash)
		"Skyshroud Condor": c.castable_only_when(_another_spell_this_turn)
		# ------------------------------------------------------------ black
		"Abandon Hope":
			c.spell(AbandonHope.new())
			c.with_object_cost(OC.times_x(OC.discarding("card")))
		# -------------------------------------------------------------- red
		"Goblin Bombardment":
			c.activated(ActivatedAbility.new("", false, [DamageEffect.new(1).any_target()],
				"Sacrifice a creature: This enchantment deals 1 damage to any target.") \
				.with_sacrifice_of("creature", _creature))
		"Scorched Earth":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)).x_targets())
			c.with_object_cost(OC.times_x(OC.discarding("land card", _land_card)))
		"Tooth and Claw":
			c.activated(ActivatedAbility.new("", false,
				[CreateTokenEffect.new("Carnivore", 3, 1, Mtg.ManaColor.R, "beast")],
				"Sacrifice two creatures: Create a 3/1 red Beast creature token named Carnivore.") \
				.with_object_cost(OC.sacrificing("creature", _creature, 2)))
		# ------------------------------------------------------------ green
		"Aluren": c.with_granted_alternative_cost(_aluren_rows)
		"Harrow":
			c.with_additional_sacrifice("land", _land)
			c.spell(HarrowSearch.new())
		# ------------------------------------------------------------- gold
		"Spontaneous Combustion":
			c.with_additional_sacrifice("creature", _creature)
			c.spell(DamageAllEffect.new(3))
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _land_card(i: CardInstance) -> bool: return i.data.is_land()


# ---------------------------------------------------------------- Medallions

## "<Colour> spells you cast cost {1} less to cast." Asked about its OWN
## source, so "you" is the Medallion's controller (two opposing Medallions
## never discount each other's spells; two of yours stack). The engine
## takes a reduction off the generic part only (CR 601.2f), X included.
static func _medallion(caster: int, data: CardData, source: CardInstance, color: int) -> int:
	if source.controller_id != caster: return 0
	return -1 if (data.color_mask() & color) != 0 else 0

static func _white_medallion(_g: MtgGame, caster: int, data: CardData, source: CardInstance) -> int:
	return _medallion(caster, data, source, Mtg.ManaColor.W)
static func _blue_medallion(_g: MtgGame, caster: int, data: CardData, source: CardInstance) -> int:
	return _medallion(caster, data, source, Mtg.ManaColor.U)
static func _black_medallion(_g: MtgGame, caster: int, data: CardData, source: CardInstance) -> int:
	return _medallion(caster, data, source, Mtg.ManaColor.B)
static func _red_medallion(_g: MtgGame, caster: int, data: CardData, source: CardInstance) -> int:
	return _medallion(caster, data, source, Mtg.ManaColor.R)
static func _green_medallion(_g: MtgGame, caster: int, data: CardData, source: CardInstance) -> int:
	return _medallion(caster, data, source, Mtg.ManaColor.G)


## "Red spells cost {2} more to cast." — every caster's (Gloom's shape).
static func _chill(_g: MtgGame, _caster: int, data: CardData, _source: CardInstance) -> int:
	return 2 if (data.color_mask() & Mtg.ManaColor.R) != 0 else 0


# ------------------------------------------------------------ Rootwater Shaman

## "You may cast Aura spells with enchant creature as though they had
## flash." — its controller only ("you may").
static func _shaman_flash(_g: MtgGame, pid: int, spell: CardInstance, source: CardInstance) -> bool:
	return pid == source.controller_id and spell.data.is_aura() \
		and spell.data.aura_target != null and spell.data.aura_target.kind == TargetSpec.Kind.CREATURE


# ------------------------------------------------------------ Skyshroud Condor

## "Cast this spell only if you've cast another spell this turn." Asked at
## announcement, the Condor itself is not counted yet (MtgGame.spells_cast_count).
static func _another_spell_this_turn(game: MtgGame, pid: int) -> String:
	return "" if game.spells_cast_count(pid) > 0 \
		else "Cast this spell only if you've cast another spell this turn"


# ---------------------------------------------------------------------- Aluren

## "Any player may cast creature spells with mana value 3 or less without
## paying their mana costs and as though they had flash." One granted row
## for every player's creature spell of PRINTED mana value 3 or less (the
## Aluren rulings: the printed cost, X is 0), and flash through that row
## only ("You can't choose to cast a creature as though it had flash via
## Aluren and still pay the mana cost").
static func _aluren_rows(_g: MtgGame, _pid: int, spell: CardInstance, _source: CardInstance) -> Array:
	if not spell.data.is_creature() or spell.data.cost.mana_value() > 3:
		return []
	return [{"label": "Cast it without paying its mana cost (Aluren)", "flash": true}]


# ---------------------------------------------------------------- Abandon Hope

## "Look at target opponent's hand and choose X cards from it. That player
## discards those cards." The caster sees the whole hand (shown to that seat
## only) and picks X of them (Mind Warp's shape, aimed at an opponent).
class AbandonHope extends ChosenDiscardEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if t == null or not t.is_player: return
		var who := t.player_id
		var names: Array = []
		for card in g.players[who].hand: names.append(card.data.card_name)
		g.reveal_information(pid, "Abandon Hope — %s's hand" % g.players[who].player_name, names)
		var left := candidates(g, who)
		var chosen: Array[CardInstance] = []
		for _i in mini(x, left.size()):
			var pick := g.agents[pid].choose_card(g, pid, left,
				"Abandon Hope: choose a card for %s to discard" % g.players[who].player_name)
			if pick == null or not left.has(pick): pick = left[0]
			chosen.append(pick)
			left.erase(pick)
		if not chosen.is_empty(): g.discard_cards(who, chosen)
	func describe() -> String:
		return "look at target opponent's hand and choose X cards from it; that player discards them"


# ---------------------------------------------------------------------- Harrow

## "Search your library for up to two basic land cards, put them onto the
## battlefield, then shuffle." Two picks, each may find nothing, one
## shuffle at the end (CR 701.19a); the lands enter untapped and are not
## land drops (the Harrow ruling).
class HarrowSearch extends SearchLibraryEffect:
	func _init() -> void:
		super("up to two basic land cards", _basic_land_card)
		to_battlefield()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for n in 2:
			g.search_library(pid, filter,
				"Harrow: search for a basic land card (%d of up to 2)" % (n + 1), true, false)
		g.shuffle_library(pid)
	static func _basic_land_card(i: CardInstance) -> bool:
		return i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0
	func describe() -> String:
		return "search your library for up to two basic land cards, put them onto the battlefield, then shuffle"
