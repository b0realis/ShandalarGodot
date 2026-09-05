extends CardScript
## Animate Dead — {1}{B} — Enchantment — Aura (2ed, uncommon)
## Oracle: Enchant creature card in a graveyard. When Animate Dead enters
##         the battlefield, return enchanted creature card to the
##         battlefield under your control. It gets -1/-0. When Animate
##         Dead leaves the battlefield, that creature's controller
##         sacrifices it.
##
## Implementation: the reference REANIMATION card — reanimates() marks it;
## the engine raises the graveyard target under the aura controller before
## attaching, and the creature is SACRIFICED when the aura leaves (the
## modern oracle's clean fix of 1994's messiest card — a sacrifice, so a
## regeneration shield cannot save it). The -1/-0 rides as a static.
## Targets EITHER graveyard — stealing the opponent's dead Shivan is the
## classic move, and yes it works.


func build() -> CardData:
	return CardData.new("Animate Dead", "{1}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD)) \
		.reanimates() \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets -1/-0.")) \
		.oracle("Enchant creature card in a graveyard. When Animate Dead enters the battlefield, return enchanted creature card to the battlefield under your control. It gets -1/-0. When Animate Dead leaves the battlefield, that creature's controller sacrifices it.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power -= 1
