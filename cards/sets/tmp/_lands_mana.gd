extends RefCounted
## Tempest (_lands_mana, Pack 9). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## Every mana source is declared in a shape the one mana planner
## (engine/mana_planner.gd — the AI's plans and the human auto-cast) reads
## without running a callback, the Mirage module's convention: fixed
## outputs, "any color" as one ability per colour (Lotus Petal, the Black
## Lotus shape), a no-{T} "{1}: Add {R}" conversion opted in with
## [method ManaAbility.with_plannable_conversion], self-sacrifice as
## [method ManaAbility.with_sacrifice] (sorted last). A land's damage to
## its controller is both the side effect that deals it and the planner's
## [member ManaAbility.pain] knowledge.
##
## The painlands — Ice Age's Adarkar Wastes shape, plus "enters tapped".
## The "doesn't untap during your next untap step" duals — the side effect
##   is MtgGame.skip_untap_during_next_step for the ACTIVATING player (CR
##   109.5: "your" untap step on an ability is its activator's).
## Reflecting Pool — a colour-choice ability (Fellwar Stone's shape) whose
##   census is every type of mana, colourless included (CR 106.7), that the
##   mana abilities of the OTHER lands its controller controls could make,
##   tapped or not and whatever their costs (the card's rulings). It never
##   asks another Reflecting Pool (or any land whose census reads other
##   lands) — such an ability has no type of its own, so a pair of Pools
##   with nothing else makes nothing (CR 106.7: "if no permanents meet the
##   stated criteria, no mana is produced").
## Eladamri's Vineyard — MAIN_PHASE_START (precombat) for EACH player; the
##   resolving trigger adds {G}{G} to that player's pool (not a mana
##   ability). Unspent, it burns under the mana-burn presets — at the end of
##   the step under modern_mana_burn, at the end of the phase under fifth.
## Ghost Town — "{0}: Return this land to its owner's hand. Activate only if
##   it's not your turn." Its AI role is `self_bounce` (the answer to an
##   opposing spell or ability aimed at it).
## Stalking Stones — an AnimateSelfEffect whose animation lasts indefinitely
##   (ContinuousEffects.Duration.INDEFINITE): it ends only when the land
##   leaves the battlefield (CR 611.2a, 400.7).
## Wasteland — Strip Mine's shape, the target limited to a land without
##   the basic supertype (live supertypes).
const F := preload("res://cards/sets/fem/_rules.gd")

## painland -> its two colours ("{T}: Add {X} or {Y}. This land deals 1
## damage to you."); every Tempest painland enters tapped.
const PAIN := {
	"Caldera Lake": [Mtg.ManaColor.U, Mtg.ManaColor.R],
	"Pine Barrens": [Mtg.ManaColor.B, Mtg.ManaColor.G],
	"Salt Flats": [Mtg.ManaColor.W, Mtg.ManaColor.B],
	"Scabland": [Mtg.ManaColor.R, Mtg.ManaColor.W],
	"Skyshroud Forest": [Mtg.ManaColor.G, Mtg.ManaColor.U],
}

## slow dual -> its two colours ("{T}: Add {X} or {Y}. This land doesn't
## untap during your next untap step.").
const SLOW := {
	"Cinder Marsh": [Mtg.ManaColor.B, Mtg.ManaColor.R],
	"Mogg Hollows": [Mtg.ManaColor.R, Mtg.ManaColor.G],
	"Rootwater Depths": [Mtg.ManaColor.U, Mtg.ManaColor.B],
	"Thalakos Lowlands": [Mtg.ManaColor.W, Mtg.ManaColor.U],
	"Vec Townships": [Mtg.ManaColor.G, Mtg.ManaColor.W],
}

static func configure(c: CardData) -> bool:
	var n := c.card_name
	if PAIN.has(n):
		c.with_enters_tapped()
		c.mana(ManaAbility.new(Mtg.ManaColor.C))
		for color in PAIN[n]:
			c.mana(ManaAbility.new(color).hurting(1).with_side_effect(_hurt.bind(1)))
		return true
	if SLOW.has(n):
		c.mana(ManaAbility.new(Mtg.ManaColor.C))
		for color in SLOW[n]:
			c.mana(ManaAbility.new(color).with_side_effect(_stay_tapped))
		return true
	match n:
		"Ancient Tomb":
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 2).hurting(2).with_side_effect(_hurt.bind(2)))
		"Blood Pet":
			# No {T}: usable the turn it arrives (CR 302.6).
			c.mana(ManaAbility.new(Mtg.ManaColor.B).without_tap().with_sacrifice())
		"Eladamri's Vineyard":
			c.triggered(TriggeredAbility.new(Mtg.EventType.MAIN_PHASE_START, _vineyard,
				"At the beginning of each player's first main phase, that player adds {G}{G}.",
				_first_main))
		"Ghost Town":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_go_home, "return this land to its owner's hand", null, true).with_ai_role(&"self_bounce")],
				"{0}: Return this land to its owner's hand. Activate only if it's not your turn.").opponents_turn_only())
		"Lotus Petal":
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color).with_sacrifice())
		"Manakin":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
		"Reflecting Pool":
			c.mana(ManaAbility.new(Mtg.ManaColor.C).with_color_choice(_pool_types).with_dynamic_amount(_pool_amount))
		"Skyshroud Elf":
			c.mana(ManaAbility.new(Mtg.ManaColor.G))
			for color in [Mtg.ManaColor.R, Mtg.ManaColor.W]:
				c.mana(ManaAbility.new(color).without_tap().with_mana_cost("{1}").with_plannable_conversion())
		"Stalking Stones":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{6}", false, [Stones.new()],
				"{6}: This land becomes a 3/3 Elemental artifact creature that's still a land. (This effect lasts indefinitely.)"))
		"Wasteland":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("", true,
				[DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonbasic land", _nonbasic_land))],
				"{T}, Sacrifice this land: Destroy target nonbasic land.").with_sacrifice_cost())
		_: return false
	return true


# ------------------------------------------------------------- the riders --

## "This land deals N damage to you": the land is the source, "you" the
## activating player.
static func _hurt(g: MtgGame, source: CardInstance, pid: int, amount: int) -> void:
	g.deal_damage(source, TargetRef.player(pid), amount)

## "This land doesn't untap during your next untap step."
static func _stay_tapped(g: MtgGame, source: CardInstance, pid: int) -> void:
	g.skip_untap_during_next_step(source, pid)


# ---------------------------------------------------------- Reflecting Pool --

## Set while a Pool takes its census: a land whose own census is asked from
## inside one (another Pool) answers nothing rather than recursing. Holds
## no object (CONTRIBUTING.md: no static may hold a CardInstance).
static var _census_depth := 0

## Every type of mana the OTHER lands [param source]'s controller controls
## could produce, in WUBRG order and colourless last.
static func _pool_types(g: MtgGame, source: CardInstance) -> Array[int]:
	var out: Array[int] = []
	if _census_depth > 0: return out
	var pid := source.controller_id
	# "Lands you tap for mana produce {X} instead" (Deep Water) applies to
	# every land of the seat, this one included.
	var becomes := int(g.players[pid].land_mana_becomes)
	var found := 0
	_census_depth += 1
	for land in g.players[pid].battlefield:
		if land == source or not land.is_land(): continue
		for ability in land.cur_mana_abilities:
			if ability.forced_output_color != 0:
				found |= ability.forced_output_color
				continue
			if ability.color_options.is_valid():
				for color in ability.color_options.call(g, land): found |= int(color)
			elif ability.dynamic_color.is_valid():
				found |= int(ability.dynamic_color.call(g, land))
			else:
				for pair in ability.produces: found |= int(pair[0])
	_census_depth -= 1
	if found != 0 and becomes != 0: found = becomes
	var order: Array[int] = Mtg.WUBRG.duplicate()
	order.append(Mtg.ManaColor.C)
	for color in order:
		if (found & color) != 0: out.append(color)
	return out

## Nothing on offer: the ability makes no mana at all (Fellwar Stone).
static func _pool_amount(g: MtgGame, source: CardInstance) -> int:
	return 0 if _pool_types(g, source).is_empty() else 1


# ------------------------------------------------------ Eladamri's Vineyard --

static func _first_main(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return bool(e.data.get("precombat", false)) and int(e.data.get("player", -1)) >= 0

## "That player adds {G}{G}" — the player whose main phase began, whoever
## controls the Vineyard, and even if it has left (the trigger is on its own).
static func _vineyard(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	AddManaEffect.new(Mtg.ManaColor.G, 2).resolve(g, s, who, null)


# --------------------------------------------------------------- Ghost Town --

## Only the object that was activated goes home (CR 400.7).
static func _go_home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.return_to_hand(s)


# ----------------------------------------------------------- Stalking Stones --

class Stones extends AnimateSelfEffect:
	func _init() -> void:
		super(Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 3, 3, ["elemental"])
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if not g.is_present(source) \
				or source.layer_timestamp != int(g.cost_paid("_source_timestamp", source.layer_timestamp)):
			return
		g.continuous.add_until_eot_animation(source.id, add_types, set_power, set_toughness,
			add_subtypes, false, ContinuousEffects.Duration.INDEFINITE)
		g.log_line("%s becomes a 3/3 Elemental artifact creature" % source.data.card_name)
		g.recalculate()
	func describe() -> String:
		return "becomes a 3/3 Elemental artifact creature that's still a land (indefinitely)"


# ---------------------------------------------------------------- Wasteland --

static func _nonbasic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0
