extends RefCounted
## Exodus (_licids, Pack 9). Licids: creatures that become Auras attached
## to a creature until their controller pays to end the effect.
##
## The conventions are cards/sets/tmp/_licids.gd's.
##
## - Dominating Licid: "You control enchanted creature" is E3's `steals`
##   flag (as_licid(..., true)), which the derived Aura carries as
##   `aura_steals` — Control Magic's control effect (CR 613.1b), ending
##   with the licid's effect or when the Aura leaves.
## - Transmogrifying Licid: an artifact creature card. As an Aura it is an
##   enchantment only (E3, CR 205.1a); its line is a layer-7c +1/+1 and a
##   layer-4 type change adding ARTIFACT to the host (CR 205.1b "in
##   addition to its other types"), so artifact removal reaches the host.
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/mir/_auras.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dominating Licid":
			c.as_licid("{1}{U}{U}", "{U}", true)
		"Transmogrifying Licid":
			c.as_licid("{1}", "{1}")
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1),
				"Enchanted creature gets +1/+1."))
			c.static_ability(StaticAbility.new(_artifact_host,
				"Enchanted creature is an artifact in addition to its other types.").changing_types())
		_: return false
	return true


static func _artifact_host(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_types |= Mtg.CardType.ARTIFACT
