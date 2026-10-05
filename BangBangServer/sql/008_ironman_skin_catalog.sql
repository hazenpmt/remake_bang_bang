BEGIN;

INSERT INTO tank_skins (
    tank_id,
    skin_key,
    display_name,
    quality_key,
    avatar_asset_key,
    preview_asset_key,
    stat_modifiers,
    is_default,
    enabled
)
SELECT
    tank.id,
    source.skin_key,
    source.display_name,
    source.quality_key,
    source.avatar_asset_key,
    source.preview_asset_key,
    '{}'::jsonb,
    source.is_default,
    TRUE
FROM tanks tank
CROSS JOIN (
    VALUES
        (
            'gangtiexia03_default',
            'Iron Man',
            NULL,
            'zh_CN/avatar/gangtiexia03.png',
            'zh_CN/avatar/gangtiexia03.png',
            TRUE
        ),
        (
            'gangtiexia04',
            'Iron Man 2',
            'A',
            'zh_CN/avatar/gangtiexia04.png',
            'zh_CN/avatar/gangtiexia04.png',
            FALSE
        ),
        (
            'gangtiexia05',
            'Iron Man 3',
            'S',
            'zh_CN/avatar/gangtiexia05.png',
            'zh_CN/avatar/gangtiexia05.png',
            FALSE
        ),
        (
            'gangtiexia_pf04',
            'MK-42',
            'SS',
            'zh_CN/avatar/gangtiexia_pf04.png',
            'zh_CN/avatar/gangtiexia_pf04.png',
            FALSE
        ),
        (
            'gangtiexia_pf01',
            'Bão Sa Mạc',
            'SS',
            'zh_CN/avatar/gangtiexia_pf01.png',
            'zh_CN/avatar/gangtiexia_pf01.png',
            FALSE
        ),
        (
            'gangtiexia_pf05',
            'Patriot',
            'SS',
            'zh_CN/avatar/gangtiexia_pf05.swf',
            'zh_CN/avatar/gangtiexia_pf05.swf',
            FALSE
        ),
        (
            'gangtiexia_pf03',
            'Dũng Sĩ Bình Minh',
            'SS',
            'zh_CN/avatar/gangtiexia_pf03.png',
            'zh_CN/avatar/gangtiexia_pf03.png',
            FALSE
        ),
        (
            'gangtiexia_pf02',
            'Chiến Cảnh Tương Lai',
            'SS',
            'zh_CN/avatar/gangtiexia_pf02.png',
            'zh_CN/avatar/gangtiexia_pf02.png',
            FALSE
        ),
        (
            'gangtiexia_pf06',
            'Hồng Liên (Iron Man)',
            'SSS',
            'zh_CN/avatar/gangtiexia_pf06.swf',
            'zh_CN/avatar/gangtiexia_pf06.swf',
            FALSE
        )
) AS source(
    skin_key,
    display_name,
    quality_key,
    avatar_asset_key,
    preview_asset_key,
    is_default
)
WHERE tank.tank_key = 'gangtiexia03'
ON CONFLICT (tank_id, skin_key) DO UPDATE
SET display_name = EXCLUDED.display_name,
    quality_key = EXCLUDED.quality_key,
    avatar_asset_key = EXCLUDED.avatar_asset_key,
    preview_asset_key = EXCLUDED.preview_asset_key,
    is_default = EXCLUDED.is_default,
    enabled = TRUE;

COMMIT;
