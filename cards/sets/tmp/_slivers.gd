extends RefCounted
## Tempest (_slivers, Pack 9). Slivers: creatures whose abilities every
## Sliver on the battlefield shares.
##
## Conventions (sth/_slivers.gd preloads the helpers at the bottom):
## - Every grant reaches EVERY Sliver on the battlefield, both players',
##   the granting Sliver included, and is re-derived on every
##   recalculation: a Sliver entering later has it at once, and it ends
##   the moment the granting Sliver leaves. "All Sliver creatures" asks
##   for a CREATURE with the Sliver type; "All Slivers" for any permanent
##   with it, so a Sliver that is not a creature has those grants too.
##   A phased-out permanent is treated as though it doesn't exist
##   (CR 702.26b).
## - A keyword or shroud grant is a layer-6 static (changing_abilities,
##   CR 613.1f, 613.7), so a later "loses flying" still wins; Muscle
##   Sliver's +1/+1 is layer 7c.
## - A granted ACTIVATED ability is appended to each Sliver's live ability
##   list — the Zombie Master shape (cards/sets/2ed/zombie_master.gd). It
##   is then that Sliver's own ability (CR 613.1f), so its controller
##   activates it and "this creature" / "this permanent" — the pump, the
##   regeneration shield, the sacrifice, the bounce — is the Sliver whose
##   ability was activated (its source, CR 113.7). One ability
##   object per granting card, shared like a printed ability is shared by
##   every copy of its card; two granting Slivers grant it twice.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Armor Sliver":
			c.static_ability(StaticAbility.new(grant_ability.bind(ActivatedAbility.new("{2}", false,
					[PumpEffect.new(0, 1).self_buff()], "{2}: This creature gets +0/+1 until end of turn."), true),
				"All Sliver creatures have \"{2}: This creature gets +0/+1 until end of turn.\"").changing_abilities())
		"Barbed Sliver":
			c.static_ability(StaticAbility.new(grant_ability.bind(ActivatedAbility.new("{2}", false,
					[PumpEffect.new(1, 0).self_buff()], "{2}: This creature gets +1/+0 until end of turn."), true),
				"All Sliver creatures have \"{2}: This creature gets +1/+0 until end of turn.\"").changing_abilities())
		"Clot Sliver":
			c.static_ability(StaticAbility.new(grant_ability.bind(ActivatedAbility.new("{2}", false,
					[RegenerateEffect.new()], "{2}: Regenerate this permanent."), false),
				"All Slivers have \"{2}: Regenerate this permanent.\"").changing_abilities())
		"Heart Sliver":
			c.static_ability(StaticAbility.new(grant_keyword.bind(Mtg.Keyword.HASTE),
				"All Sliver creatures have haste.").changing_abilities())
		"Horned Sliver":
			c.static_ability(StaticAbility.new(grant_keyword.bind(Mtg.Keyword.TRAMPLE),
				"All Sliver creatures have trample.").changing_abilities())
		"Mindwhip Sliver":
			# Activated by the Sliver's controller, so "as a sorcery" is that
			# player's main phase with an empty stack (CR 602.5d).
			c.static_ability(StaticAbility.new(grant_ability.bind(ActivatedAbility.new("{2}", false,
					[RandomHandDiscardEffect.new(1)],
					"{2}, Sacrifice this permanent: Target player discards a card at random. Activate only as a sorcery.") \
					.with_sacrifice_cost().only_if(MA.sorcery_speed), false),
				"All Slivers have \"{2}, Sacrifice this permanent: Target player discards a card at random. Activate only as a sorcery.\"").changing_abilities())
		"Mnemonic Sliver":
			c.static_ability(StaticAbility.new(grant_ability.bind(ActivatedAbility.new("{2}", false,
					[DrawEffect.new(1)], "{2}, Sacrifice this permanent: Draw a card.").with_sacrifice_cost(), false),
				"All Slivers have \"{2}, Sacrifice this permanent: Draw a card.\"").changing_abilities())
		"Muscle Sliver":
			c.static_ability(StaticAbility.new(_muscle, "All Sliver creatures get +1/+1."))
		"Talon Sliver":
			c.static_ability(StaticAbility.new(grant_keyword.bind(Mtg.Keyword.FIRST_STRIKE),
				"All Sliver creatures have first strike.").changing_abilities())
		"Winged Sliver":
			c.static_ability(StaticAbility.new(grant_keyword.bind(Mtg.Keyword.FLYING),
				"All Sliver creatures have flying.").changing_abilities())
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## Is [param inst] a Sliver the grant reaches: "All Sliver creatures"
## ([param creatures_only]) or "All Slivers" (any permanent of the type)?
static func is_sliver(inst: CardInstance, creatures_only: bool) -> bool:
	return not inst.phased_out and inst.has_subtype("sliver") \
		and (not creatures_only or inst.is_creature())

## Hand [param ability] to every Sliver on the battlefield (layer 6).
static func grant_ability(g: MtgGame, _s: CardInstance, ability: ActivatedAbility,
		creatures_only: bool) -> void:
	for inst in g.all_battlefield():
		if is_sliver(inst, creatures_only):
			inst.cur_activated_abilities.append(ability)

## "All Sliver creatures have <keyword>." (layer 6).
static func grant_keyword(g: MtgGame, _s: CardInstance, keyword: int) -> void:
	for inst in g.all_battlefield():
		if is_sliver(inst, true) and not inst.cur_keywords.has(keyword):
			inst.cur_keywords.append(keyword)

## "All Sliver creatures get +1/+1." (layer 7c).
static func _muscle(g: MtgGame, _s: CardInstance) -> void:
	for inst in g.all_battlefield():
		if is_sliver(inst, true):
			inst.cur_power += 1
			inst.cur_toughness += 1

## "Return this permanent to its owner's hand" — the Sliver that activated
## it, only while it is still that object on the battlefield (CR 400.7)
## and phased in (CR 702.26b).
static func return_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.return_to_hand(s)
