const USERNAME_PATTERN = /^[a-z0-9_]{6,15}$/;
const ADMIN_LOGIN_USERNAME = "admin";
const DISPLAY_NAME_PATTERN = /^[\p{L}\p{N}]+(?: [\p{L}\p{N}]+)*$/u;
const CHAT_MESSAGE_MAX_LENGTH = 120;
const RESERVED_DISPLAY_NAMES = new Set([
  "admin",
  "administrator",
  "gm",
  "gamemaster",
  "mod",
  "moderator",
  "system",
  "hethong",
  "hệthống",
  "quantri",
  "quảntrị",
]);

export function normalizeUsername(value) {
  return String(value ?? "").normalize("NFKC").trim().toLowerCase();
}

export function validateCredentials(body) {
  const username = normalizeUsername(body?.username);
  const password = String(body?.password ?? "");

  if (!USERNAME_PATTERN.test(username)) {
    return {
      ok: false,
      message: "Tài khoản phải dài 6-15 ký tự, chỉ gồm chữ thường, số hoặc dấu gạch dưới.",
    };
  }

  if (password.length < 6 || password.length > 15) {
    return {
      ok: false,
      message: "Mật khẩu phải dài từ 6 đến 15 ký tự.",
    };
  }

  return { ok: true, username, password };
}

export function validateLoginCredentials(body) {
  const username = normalizeUsername(body?.username);
  const password = String(body?.password ?? "");

  if (
    username !== ADMIN_LOGIN_USERNAME &&
    !USERNAME_PATTERN.test(username)
  ) {
    return {
      ok: false,
      message: "Tên đăng nhập không đúng định dạng.",
    };
  }

  if (password.length < 6 || password.length > 15) {
    return {
      ok: false,
      message: "Mật khẩu phải dài từ 6 đến 15 ký tự.",
    };
  }

  return { ok: true, username, password };
}

export function validateCharacter(body, options = {}) {
  const displayName = String(body?.display_name ?? "").normalize("NFKC").trim();
  const gender = String(body?.gender ?? "");
  const allowAdminName = options.allowAdminName === true;

  if (Array.from(displayName).length < 3 || Array.from(displayName).length > 10) {
    return {
      ok: false,
      message: "Tên nhân vật phải có từ 3 đến 10 ký tự.",
    };
  }

  if (!DISPLAY_NAME_PATTERN.test(displayName)) {
    return {
      ok: false,
      message: "Tên chỉ được gồm chữ, số và một khoảng trắng giữa các từ.",
    };
  }

  if (/^\p{N}+$/u.test(displayName)) {
    return {
      ok: false,
      message: "Tên nhân vật không được chỉ gồm số.",
    };
  }

  const compactName = displayName.toLocaleLowerCase("vi").replaceAll(" ", "");
  const isAdminNameException = allowAdminName && compactName === "admin";
  if (RESERVED_DISPLAY_NAMES.has(compactName) && !isAdminNameException) {
    return {
      ok: false,
      message: "Tên này được dành riêng cho hệ thống hoặc quản trị viên.",
    };
  }

  if (gender !== "male" && gender !== "female") {
    return { ok: false, message: "Bạn phải chọn nhân vật nam hoặc nữ." };
  }

  return { ok: true, displayName, gender };
}

export function validateChatMessage(body, maximumLength = CHAT_MESSAGE_MAX_LENGTH) {
  const message = String(body?.message ?? "")
    .normalize("NFKC")
    .replace(/\s+/gu, " ")
    .trim();
  const length = Array.from(message).length;

  if (length === 0) {
    return { ok: false, message: "Tin nhắn không được để trống." };
  }
  if (length > maximumLength) {
    return {
      ok: false,
      message: `Tin nhắn chỉ được dài tối đa ${maximumLength} ký tự.`,
    };
  }

  return { ok: true, message };
}
