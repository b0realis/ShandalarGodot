extends RefCounted
## Optional adventure metadata for Pack 2. No art or quest scripts are loaded here.
const DESCRIPTOR := {"pack": "pack-2", "title": "The Last Refuge", "salt": 0x46454D, "palette": "last_refuge",
		"cards_unlock": "liberated",
		"provider": "res://game/adventure/expansions/refuge_content.gd",
		"required_markers": ["port", "castle"], "required_sites": [1, 2, 3, 4, 5], "pledges": 5, "mana_links": false, "progress_schema": {"quests": 5, "max_stage": 2, "max_pending": 60},
		"castle_name": "Ebon Crown", "generator": "Last Refuge (32x32 from 1997 terrain)",
		"pictures": {"refuge_harbor": "res://game/adventure/expansions/art/refuge_harbor.png", "refuge_castle": "res://game/adventure/expansions/art/refuge_castle.png"},
		"sprites": {"port": ["res://game/adventure/expansions/art/refuge_port_map.png", 160.0], "castle": ["res://game/adventure/expansions/art/refuge_castle_map.png", 192.0]}}
