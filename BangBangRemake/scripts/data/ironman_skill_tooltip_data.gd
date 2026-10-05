class_name IronmanSkillTooltipData
extends RefCounted

## Single source for the three Iron Man descriptions shown in Tank and battle.
## Keep the wording here identical to the approved Tank-panel text.

const SKILL_TOOLTIPS := [
	{
		"title": "Hạt Năng Lượng",
		"cooldown": "6 s",
		"height": 472.0,
		"description": (
			"[color=#ffffff]Skill này bao gồm hiệu quả chủ động và bị động.[/color]\n\n"
			+ "[color=#ffe20b][b]Bị Động:[/b][/color] "
			+ "[color=#ffffff]Năng lượng tụ lại thành Khiên, khiên này hấp thụ ST bằng "
			+ "[color=#55ff55][b]30%[/b][/color] giới hạn HP. Nếu khiên bị phá vỡ sẽ gây "
			+ "[color=#ff9b1a][b](236% × Tấn Công)[/b][/color] ST Vật Lý cho địch xung quanh, "
			+ "sau [color=#55ff55][b]15s[/b][/color] sẽ nhận lại Khiên này.[/color]\n\n"
			+ "[color=#ffe20b][b]Chủ Động:[/b][/color] "
			+ "[color=#ffffff]Bắn pháo về hướng chỉ định, kẻ địch đầu tiên va chạm sẽ lập tức "
			+ "phát nổ, gây cho địch xung quanh "
			+ "[color=#ff9b1a][b](267% × Tấn Công)[/b][/color] ST Vật Lý và giảm "
			+ "[color=#55ff55][b]75%[/b][/color] tốc độ di chuyển trong "
			+ "[color=#55ff55][b]2.5s[/b][/color]. Nếu mục tiêu đang bị giảm tốc bởi "
			+ "[E - Đạn Không Kích], sẽ choáng thêm "
			+ "[color=#55ff55][b]1s[/b][/color].[/color]\n\n"
			+ "[color=#ff3030][b]Không gây ST lên Kiến Trúc.[/b][/color]"
		),
	},
	{
		"title": "Đạn Không Kích",
		"cooldown": "8 s",
		"height": 288.0,
		"description": (
			"[color=#ffffff]Bắn đạn tại nơi chỉ định trong "
			+ "[color=#55ff55][b]3s[/b][/color], cứ "
			+ "[color=#55ff55][b]0.5s[/b][/color] gây "
			+ "[color=#ff9b1a][b](75% × Tấn Công)[/b][/color] ST Vật Lý. Tất cả địch trong "
			+ "khu vực bị giảm tốc [color=#55ff55][b]50%[/b][/color]. Nếu địch trong "
			+ "[color=#55ff55][b]1s[/b][/color] bị [Hạt Năng Lượng] đánh trúng, sẽ choáng "
			+ "thêm [color=#55ff55][b]1s[/b][/color].[/color]\n\n"
			+ "[color=#ff3030][b]Giảm 50% ST lên Kiến Trúc.[/b][/color]"
		),
	},
	{
		"title": "Tia Tan Rã",
		"cooldown": "20 s",
		"height": 376.0,
		"description": (
			"[color=#ffffff]Tạo một tia năng lượng. Mỗi "
			+ "[color=#55ff55][b]0.2s[/b][/color] gây "
			+ "[color=#ff9b1a][b](125% × Tấn Công)[/b][/color] ST Vật Lý và chuyển "
			+ "[color=#55ff55][b]25%[/b][/color] ST gây ra thành HP bản thân trong "
			+ "[color=#55ff55][b]4s[/b][/color]. Khi bắt đầu dẫn dắt sẽ nhận ngay Khiên bị "
			+ "động. Trong lúc tạo tia, tank không bị khống chế, giảm "
			+ "[color=#55ff55][b]50%[/b][/color] ST Năng Lượng phải nhận, nhưng không thể "
			+ "di chuyển, tàng hình hoặc thi triển skill khác.[/color]\n\n"
			+ "[color=#ffffff]Sau [color=#55ff55][b]1s[/b][/color], dùng lại skill để hủy "
			+ "tia bắn.[/color]\n\n"
			+ "[color=#ff3030][b]Không gây ST lên Kiến Trúc.[/b][/color]"
		),
	},
]

const SHIELD_TOOLTIP := {
	"title": "Khiên Thép",
	"height": 108.0,
	"show_metadata": false,
	"title_font_size": 14,
	"body_font_size": 12,
	"description": (
		"[color=#ffffff][lb]Giới thiệu[rb]\n"
		+ "Nhận Khiên hút ST, khi bị phá vỡ gây ST lên đơn vị xung quanh, "
		+ "sau 15s sẽ nhận lại khiên.[/color]"
	),
}
