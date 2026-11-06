extends RefCounted
## Urza's Legacy (_costs, Pack 10). Additional and alternative costs and
## the effects that read them: Pyromancy.
##
## Pyromancy's "Discard a card at random" is part of the COST (CR 602.2b):
## engine package E7's random discard (engine/additional_object_costs.gd),
## rolled on the game's seeded RNG as the cost is paid, never the ability
## itself choosing — so an empty hand cannot pay it. The damage reads the
## cost's receipt: the discarded card's mana value as a card (an {X} in its
## cost counts as 0, CR 202.3e). The enchantment is the source, by last
## known information if it has left (CR 608.2h).
## tests/cards/test_pack_10_B2_choices.gd pins it.
const OC := preload("res://engine/additional_object_costs.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Pyromancy":
			c.activated(ActivatedAbility.new("{3}", false, [DiscardedBurn.new()],
				"{3}, Discard a card at random: This enchantment deals damage to any target equal to the mana value of the discarded card.") \
				.with_object_cost(OC.discarding_at_random()))
		_: return false
	return true


## The damage is the mana value on the cost's receipt.
class DiscardedBurn extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
		with_ai_role(&"discarded_mana_value_damage")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var mv := 0
		for row in g.cost_paid("_object_costs", []):
			if String(row.get("operation", "")) == "discard":
				mv += int(row.get("mana_value", 0))
		if mv > 0:
			g.deal_damage(s, t, mv)
	func describe() -> String:
		return "deals damage to any target equal to the mana value of the discarded card"
