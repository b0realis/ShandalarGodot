extends RefCounted
## Typed effects reuse the shared target, payment, prevention and AI paths.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")
const T := preload("res://cards/sets/por/_triggers.gd")
const P := preload("res://cards/sets/por/_spells.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Alaborn Veteran": c.activated(early(PumpEffect.new(2, 2)))
		"Steam Catapult": c.activated(early(DestroyEffect.new(TargetSpec.creature("target tapped creature", S._tapped))))
		"Temple Elder": c.activated(early(GainLifeEffect.new(1)))
		"Apprentice Sorcerer": c.activated(early(DamageEffect.new(1).any_target()))
		"Talas Researcher": c.activated(early(DrawEffect.new(1)))
		"Goblin Firestarter": c.activated(F._ability("", false, DamageEffect.new(1).any_target()).with_sacrifice_cost().your_turn_only().before_step(Mtg.Step.DECLARE_ATTACKERS))
		"Armored Galleon", "Steam Frigate": c.with_attack_needs_defender_land("island")
		"Talas Warrior": c.static_ability(StaticAbility.new(S._unblockable, c.oracle_text))
		"Goblin Glider", "Goblin Raider", "Ogre Taskmaster": c.static_ability(StaticAbility.new(S._no_block, c.oracle_text))
		"Ironhoof Ox", "Norwood Riders": c.static_ability(StaticAbility.new(P._one_blocker, c.oracle_text))
		"Prowling Nightstalker": c.static_ability(StaticAbility.new(_black_blockers, c.oracle_text))
		"Extinguish": c.spell(CounterEffect.new("target sorcery spell", S._sorcery))
		"False Summoning": c.spell(CounterEffect.new("target creature spell", F._creature))
		"Temporal Manipulation": c.spell(ExtraTurnEffect.new())
		"Just Fate":
			c.castable_only_when(S._attacked)
			c.spell(DestroyEffect.new(TargetSpec.creature("target attacking creature").with_game_filter(S._attacking)))
		"Remove":
			c.castable_only_when(S._attacked)
			c.spell(ReturnToHandEffect.new(TargetSpec.creature("target attacking creature").with_game_filter(S._attacking)))
		"Rally the Troops":
			c.castable_only_when(S._attacked)
			c.spell(F.Action.new(P._mobilize, "untap all creatures you control", null, true).with_ai_role(&"untap_team"))
		"Warrior's Stand":
			c.castable_only_when(S._attacked)
			c.spell(MassPumpEffect.new(2, 2, "creatures you control").yours_only())
		"Righteous Charge": c.spell(MassPumpEffect.new(2, 2, "creatures you control").yours_only())
		"Chorus of Woe": c.spell(MassPumpEffect.new(1, 0, "creatures you control").yours_only())
		"Wind Sail":
			var e := PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])
			e.target_max = 2
			c.spell(e)
		"Bloodcurdling Scream": c.spell(PumpEffect.new(0, 0).x_power())
		"Bargain":
			var e := DrawEffect.new(1)
			e.target_spec = TargetSpec.opponent()
			c.spell(e).spell(GainLifeEffect.new(7))
			c.spell_effects[0].with_ai_role(&"opponent_draw_gain_life")
		"Ancient Craving": c.spell(DrawEffect.new(3)).spell(GainLifeEffect.new(-3))
		"Dark Offering": c.spell(DestroyEffect.new(TargetSpec.creature("target nonblack creature", S._nonblack))).spell(GainLifeEffect.new(3))
		"Kiss of Death":
			var e := DamageEffect.new(4)
			e.target_spec = TargetSpec.opponent()
			c.spell(e).spell(GainLifeEffect.new(4))
		"Dakmor Plague": c.spell(DamageAllEffect.new(3).and_each_player())
		"Tremor": c.spell(DamageAllEffect.new(1, "each creature without flying", S._not_flying))
		"Jagged Lightning":
			var e := DamageEffect.new(3).target_creature()
			e.target_min = 2
			e.target_max = 2
			c.spell(e)
		"Undo":
			var e := ReturnToHandEffect.new()
			e.target_min = 2
			e.target_max = 2
			c.spell(e)
		"Coercion": c.spell(RevealedDiscard.new())
		"Cruel Edict": c.spell(Edict.new())
		"Festival of Trokin": c.spell(CreatureLife.new())
		"Goblin War Strike": c.spell(GoblinDamage.new())
		_: return false
	return true

static func early(effect: EffectBase) -> ActivatedAbility:
	return F._ability("", true, effect).your_turn_only().before_step(Mtg.Step.DECLARE_ATTACKERS)

static func _black_blockers(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "black creatures", "filter": P._black})

class RevealedDiscard extends ChosenDiscardEffect:
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var names: Array = []
		for i in g.players[t.player_id].hand: names.append(i.data.card_name)
		g.reveal_information(-1, "Revealed hand", names)
		super(g, s, pid, t, x)

class Edict extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
		with_ai_role(&"opponent_sacrifice_creature")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var choices := g.players[t.player_id].creatures()
		if choices.is_empty(): return
		var pick := g.agents[t.player_id].choose_card(g, t.player_id, choices, "Choose a creature to sacrifice", false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		g.sacrifice_permanent(pick)
	func describe() -> String: return "target opponent sacrifices a creature of their choice"

class CreatureLife extends GainLifeEffect:
	func _init() -> void:
		super(2)
		with_ai_role(&"life_per_own_creature")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.adjust_life(pid, 2 * g.players[pid].creatures().size())
	func describe() -> String: return "gain 2 life for each creature you control"

class GoblinDamage extends DamageEffect:
	func _init() -> void:
		super(0)
		target_player()
		with_ai_role(&"goblin_count_damage")
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var count := 0
		for i in g.players[pid].battlefield:
			if i.has_subtype("goblin"): count += 1
		g.deal_damage(s, t, count)
	func describe() -> String: return "deal damage equal to the number of Goblins you control"
