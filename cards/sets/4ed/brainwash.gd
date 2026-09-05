extends CardScript
## Brainwash — {W} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature can't attack unless its controller pays {3}.
##
## Implementation: an ATTACK COST (CardInstance.cur_attack_costs, new) —
## the tax is checked and paid as attackers are declared (CR 508.1g), not
## before and not after. Declaring an attack the controller cannot pay for
## is REFUSED with the reason, and a declaration the engine has to refuse
## for any reason leaves nothing spent, because every cost of every declared
## attacker is checked before any of them is paid.
##
## The payer is the enchanted creature's CONTROLLER, which for a stolen
## creature is the thief — "its controller", read live.
##
## Not a ban: a player with three mana open simply pays. That is the whole
## card — a one-mana Aura that makes every attack cost four.


func build() -> CardData:
	return CardData.new("Brainwash", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_tax, "Enchanted creature can't attack unless its controller pays {3}.")) \
		.oracle("Enchant creature\nEnchanted creature can't attack unless its "
			+ "controller pays {3}.")


static func _tax(game: MtgGame, source: CardInstance) -> void:
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_attack_costs.append({
		"desc": "its controller pays {3}",
		"can_pay": _can_pay,
		"pay": _pay,
	})


static func _can_pay(game: MtgGame, pid: int) -> bool:
	return game.can_afford_cost(pid, ManaCost.parse("{3}"))


static func _pay(game: MtgGame, pid: int) -> void:
	game.try_pay(pid, ManaCost.parse("{3}"))
