class_name ProfileProgression
extends RefCounted

## Original character EXP requirements from CharLevelTemplate_table.xml.
const EXPERIENCE_MAX_BY_LEVEL: Array[int] = [
	150,
	350,
	550,
	800,
	1000,
	1250,
	1600,
	2000,
	2500,
	3300,
	4500,
	5800,
	6800,
	8300,
	10000,
	13000,
	15000,
	19000,
	22000,
	27000,
	42000,
	50000,
	60000,
	73000,
	87000,
	156000,
	191000,
	227000,
	270000,
	330000,
	363000,
	399300,
	439200,
	483200,
	531500,
	956700,
	1148000,
	1377600,
	1653200,
	1983800,
	-1,
]
const OFFLINE_PREVIEW: Dictionary = {
	"level": 15,
	"experience": 1548,
	"experience_max": 13000,
	"xu": 11207,
	"locked_xu": 23670,
	"silver": 5142255,
}


static func experience_max_for_level(level: int) -> int:
	var safe_level := clampi(level, 0, EXPERIENCE_MAX_BY_LEVEL.size() - 1)
	return maxi(0, EXPERIENCE_MAX_BY_LEVEL[safe_level])
