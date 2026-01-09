class_name Weapon extends Items

enum WeaponType { SWORD, AXE, LANCE, FIRE, WIND, THUNDER, BOW, LIGHT, DARK }
enum Advantage { DISADVANTAGE = -1, NEUTRAL = 0, ADVANTAGE = 1 }

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var weapon_rank: StringName = "E" # Future gating (training, promotions)
@export_range(0, 50) var might: int = 0
@export_range(0, 200) var hit: int = 0
@export_range(0, 200) var crit: int = 0
@export_range(1, 10) var min_range: int = 1
@export_range(1, 10) var max_range: int = 1
@export var is_magic: bool = false # Drives RES vs DEF and SFX/VFX routing

func has_range(distance: int) -> bool:
	# Check if distance is within weapon reach.
	return distance >= min_range and distance <= max_range

func triangle_vs(defender: Weapon) -> Advantage:
	# Fire Emblem-style physical + elemental triangle.
	if defender == null:
		return Advantage.NEUTRAL
	match weapon_type:
		WeaponType.SWORD:
			if defender.weapon_type == WeaponType.AXE:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.LANCE:
				return Advantage.DISADVANTAGE
		WeaponType.AXE:
			if defender.weapon_type == WeaponType.LANCE:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.SWORD:
				return Advantage.DISADVANTAGE
		WeaponType.LANCE:
			if defender.weapon_type == WeaponType.SWORD:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.AXE:
				return Advantage.DISADVANTAGE
		WeaponType.FIRE:
			if defender.weapon_type == WeaponType.WIND:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.THUNDER:
				return Advantage.DISADVANTAGE
		WeaponType.WIND:
			if defender.weapon_type == WeaponType.THUNDER:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.FIRE:
				return Advantage.DISADVANTAGE
		WeaponType.THUNDER:
			if defender.weapon_type == WeaponType.FIRE:
				return Advantage.ADVANTAGE
			if defender.weapon_type == WeaponType.WIND:
				return Advantage.DISADVANTAGE
	return Advantage.NEUTRAL
