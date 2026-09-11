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
			_apply, "Enchanted creature gets +0/+2.")) \
		.static_ability(StaticAbility.new(
			_reach, "Enchanted creature has reach.").changing_abilities()) \
		.oracle("Enchant creature\nEnchanted creature gets +0/+2 and has reach.")


## TWO STATICS, one per CR 613 layer (613.1): the +0/+2 is layer 7c and
## the reach is layer 6, and only the second is timestamped against an
## ability loss.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	var host := _host(game, source)
	if host != null:
		host.cur_toughness += 2


static func _reach(game: MtgGame, source: CardInstance) -> void:
	var host := _host(game, source)
	if host != null and not host.cur_keywords.has(Mtg.Keyword.REACH):
		host.cur_keywords.append(Mtg.Keyword.REACH)


static func _host(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host
