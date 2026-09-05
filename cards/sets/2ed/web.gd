extends CardScript
## Web — {G} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant creature
##         Enchanted creature gets +0/+2 and has reach.
##
## Implementation: a static adding +0/+2 and the REACH keyword to the
## host. Reach is what CombatState checks alongside flying, so a webbed
## ground creature can block a Serra Angel — for one green mana, at
## instant... no, sorcery speed, which is the catch.


func build() -> CardData:
	return CardData.new("Web", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature gets +0/+2 and has reach.")) \
		.oracle("Enchant creature\nEnchanted creature gets +0/+2 and has reach.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_toughness += 2
	if not host.cur_keywords.has(Mtg.Keyword.REACH):
		host.cur_keywords.append(Mtg.Keyword.REACH)
