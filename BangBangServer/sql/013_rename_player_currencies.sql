BEGIN;

ALTER TABLE player_currencies
    RENAME COLUMN gold TO xu;

ALTER TABLE player_currencies
    RENAME COLUMN crystal TO locked_xu;

ALTER TABLE player_currencies
    RENAME COLUMN coupon TO silver;

COMMENT ON COLUMN player_currencies.xu IS
    'Xu thường, hiển thị bằng biểu tượng tờ tiền màu vàng.';
COMMENT ON COLUMN player_currencies.locked_xu IS
    'Xu khóa, hiển thị bằng biểu tượng tờ tiền màu xanh.';
COMMENT ON COLUMN player_currencies.silver IS
    'Bạc, hiển thị bằng biểu tượng đồng bạc tròn.';

COMMIT;
