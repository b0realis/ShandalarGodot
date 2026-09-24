extends RefCounted
## Descriptive effect shapes for public-information planning. Card names
## are mapped here; the player policy consumes the shapes, not card names.
static func apply(c: CardData) -> void:
	if c.spell_effects.is_empty(): return
	var shapes := {
		"Forked Lightning": "divided_creature_damage", "Burning Cloak": "pump_then_damage_two",
		"Spitting Earth": "mountain_damage", "Final Strike": "sacrifice_power_damage",
		"Last Chance": "extra_turn_then_lose", "Prosperity": "both_players_draw_x",
		"Balance of Power": "draw_hand_difference", "Theft of Dreams": "draw_tapped_enemies",
		"Baleful Stare": "reveal_opponent_draw", "Withering Gaze": "reveal_opponent_draw",
		"Cruel Bargain": "draw_four_half_life", "Ancestral Memories": "select_two_of_seven",
		"Omen": "order_three_cantrip", "Gift of Estates": "catch_up_plains",
		"Summer Bloom": "extra_land_plays", "Mind Rot": "opponent_discards_two",
		"Scorching Winds": "damage_attackers_one", "Deep Wood": "attacker_fog",
		"Harsh Justice": "reflect_attack_damage", "Blessed Reversal": "life_per_attacker",
		"Fruition": "life_per_forest", "Renewing Dawn": "life_per_enemy_mountain",
		"Starlight": "life_per_enemy_black_creature",
	}
	if shapes.has(c.card_name): c.spell_effects[0].with_ai_role(StringName(shapes[c.card_name]))
