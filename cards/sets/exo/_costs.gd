extends RefCounted
## Exodus (_costs, Pack 9). Additional and alternative costs, upkeep costs and cost modifiers.
##
## The additional costs Exodus prints: X life (Hatred, Necrologia —
## CardData.with_additional_life, X announced although no {X} is printed),
## X creature cards (Aether Tide), a creature (Culling the Weak), a card at
## random (Sonic Burst — E7's random discard, rolled as it is paid, after
## the target is chosen: the ruling), a card put from the hand on top of
## the library (Penance — E7). Sphere of Resistance taxes every spell,
## every player's (a static artifact: stopped while tapped under the 1997
## rules). Tests: tests/cards/test_pack_9_B2_costs_sth_exo.gd.
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Penance":
			c.activated(ActivatedAbility.new("", false,
				[SourceShieldEffect.new(SourceShieldEffect.Victims.ANY, SourceShieldEffect.Action.PREVENT) \
					.from_sources("a black or red source", _black_or_red)],
				"Put a card from your hand on top of your library: The next time a black or red source of your choice would deal damage this turn, prevent that damage.") \
				.with_object_cost(OC.putting_on_top()))
		# ------------------------------------------------------------- blue
		"Aether Tide":
			c.spell(ReturnToHandEffect.new(TargetSpec.creature()).x_targets())
			c.with_object_cost(OC.times_x(OC.discarding("creature card", _creature_card)))
		# ------------------------------------------------------------ black
		"Culling the Weak":
			c.with_additional_sacrifice("creature", _creature)
			c.spell(AddManaEffect.new(Mtg.ManaColor.B, 4))
		"Hatred":
			c.with_additional_life(0, true)
			c.spell(PumpEffect.new(0, 0).x_power())
		"Necrologia":
			c.castable_only_when(_your_end_step)
			c.with_additional_life(0, true)
			c.spell(DrawEffect.new(0).x_cards())
		# -------------------------------------------------------------- red
		"Sonic Burst":
			c.spell(DamageEffect.new(4).any_target())
			c.with_object_cost(OC.discarding_at_random())
		# --------------------------------------------------------- artifact
		"Sphere of Resistance": c.with_cost_modifier(_sphere)
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()


## "a black or red source" — named as the shield is made (CR 609.7a).
static func _black_or_red(_g: MtgGame, source: CardInstance, _pid: int) -> bool:
	return (source.cur_colors & (Mtg.ManaColor.B | Mtg.ManaColor.R)) != 0


## "Cast this spell only during your end step."
static func _your_end_step(game: MtgGame, pid: int) -> String:
	if game.active_player == pid and game.current_step() == Mtg.Step.END:
		return ""
	return "Cast this spell only during your end step"


## "Spells cost {1} more to cast." — every spell, every player's.
static func _sphere(_g: MtgGame, _caster: int, _data: CardData, _source: CardInstance) -> int:
	return 1
