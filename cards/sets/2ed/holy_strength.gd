extends CardScript
## Holy Strength — {W} — Enchantment — Aura (Alpha, common)
## Oracle: Enchant creature. Enchanted creature gets +1/+2.
##
## Implementation: the reference example of an AURA. `.enchants(...)` makes
## the card cast targeting a creature and enter attached to it; the
## StaticAbility applies +1/+2 to whatever it is attached to on every
## continuous-effects pass. When the enchanted creature leaves the
## battlefield, the state-based action sweep puts the aura in the graveyard
## (CR 704.5m) — no code needed here for that.


func build() -> CardData:
	return CardData.new("Holy Strength", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature gets +1/+2.")) \
		.oracle("Enchant creature. Enchanted creature gets +1/+2.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_power += 1
	host.cur_toughness += 2
