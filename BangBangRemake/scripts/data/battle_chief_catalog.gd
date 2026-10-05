extends RefCounted

## Tù trưởng Maya: dữ liệu được chép từ các bảng XML gốc.
## Tách riêng khỏi map runtime để map khác có thể dùng lại và các
## chỉ số có thể chỉnh tại một chỗ.

const TEAM_1_TEMPLATE_ID := 2102
const TEAM_2_TEMPLATE_ID := 2103
const LEVEL_TEMPLATE_ID := 2035
const ARMS_TEMPLATE_ID := 6130501
const EXHIBIT_ID := 1020
const BODY_COMPONENT_ID := 3956
const SKILL_ID := 1000041
const BULLET_EXHIBIT_ID := 18

const DISPLAY_NAME := "Tù Trưởng"
const RESPAWN_SECONDS := 30.0
const HIT_RADIUS := 36.0

# AINpcLevelTemplate 2035, sau khi nhân hệ số AINpcArmsTemplate 6130501.
const MAXIMUM_HEALTH := 1494
const BASIC_ATTACK_DAMAGE := 302.0
const PENETRATION := 180.0
const PHYSICAL_ARMOR := 225.0
const ENERGY_SHIELD := 225.0
const MOVE_SPEED := 90.0

# Arms XML + SkillTemplate 1000041.
const ALERT_RANGE := 600.0
const ATTACK_RANGE := 480.0
const ATTACK_INTERVAL_SECONDS := 4.0
const BURST_SHOTS := 3
const BURST_BREAK_SECONDS := 0.3
const MUZZLE_OFFSET := 24.0
const PROJECTILE_LIFETIME_SECONDS := 2.0
const PROJECTILE_SPEED := ATTACK_RANGE / PROJECTILE_LIFETIME_SECONDS

const SOURCE_BODY := "rez/zh_CN/tank/body/tuzhu04_body.png"
const SOURCE_BULLET := "rez/zh_CN/tank/bullet/changmao.png"
const SOURCE_IMPACT := "rez/zh_CN/swf/tank/bullet/normal_bullet_blow.swf"
const SOURCE_DEATH := "rez/zh_CN/swf/tank/death/oil_death.swf"


static func combat_stats() -> Dictionary:
	return {
		"hit_points": MAXIMUM_HEALTH,
		"basic_attack_damage": BASIC_ATTACK_DAMAGE,
		"penetration": PENETRATION,
		"physical_armor": PHYSICAL_ARMOR,
		"energy_shield": ENERGY_SHIELD,
		"move_speed": MOVE_SPEED,
		"fire_rate": 60.0 / ATTACK_INTERVAL_SECONDS,
		"attack_range": ATTACK_RANGE,
		"critical_chance_percent": 0.0,
		"critical_damage_percent": 100.0,
		"damage_type": "physical",
	}
