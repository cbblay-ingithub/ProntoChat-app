# CLOUDINARY_SETUP.md — ProntoChat

Running checklist of every Cloudinary console input and setting required.
Updated as work progresses. Each item must be confirmed before launch.

---

## Console Inputs Needed (values from your account)

- [x] **Cloud Name**: `dj4miyael`
  - Where to find: Cloudinary Dashboard → Product Environment → Cloud Name
  - Where it goes: `CLOUDINARY_CLOUD_NAME` dart-define / build config
  - Value: `dj4miyael`

- [x] **Upload Preset: `pc_avatar`** (unsigned)
  - Where to find: Settings → Upload → Upload presets
  - Confirmed: exists, unsigned
  - Where it goes: `CLOUDINARY_PRESET_AVATAR` dart-define
  - Value: `pc_avatar`

- [x] **Upload Preset: `pc_logo`** (unsigned)
  - Where to find: Settings → Upload → Upload presets
  - Confirmed: exists, unsigned
  - Where it goes: `CLOUDINARY_PRESET_LOGO` dart-define
  - Value: `pc_logo`

- [x] **Upload Preset: `pc_chat`** (unsigned)
  - Where to find: Settings → Upload → Upload presets
  - Confirmed: exists, unsigned
  - Where it goes: `CLOUDINARY_PRESET_CHAT` dart-define
  - Value: `pc_chat`

- [x] **Max Upload File Size (plan limit)**: `10 MB` (10,485,760 bytes)
  - Where to find: Cloudinary Dashboard → Account → Plan details
  - Free tier default: 10 MB per file
  - Where it goes: `kMaxUploadBytes` constant in `media_config.dart`

- [x] **Named Transformation: `avatar_sm`** (64px)
  - Where to find: Cloudinary Console → Transformations → Named Transformations
  - Used as: `t_avatar_sm` in URLs

- [x] **Named Transformation: `avatar_lg`** (256px)
  - Used as: `t_avatar_lg` in URLs

- [x] **Named Transformation: `logo_sm`** (128px)
  - Used as: `t_logo_sm` in URLs

- [x] **Named Transformation: `logo_lg`** (512px)
  - Used as: `t_logo_lg` in URLs

- [x] **Named Transformation: `chat_thumb`** (480px)
  - Used as: `t_chat_thumb` in URLs

- [x] **Named Transformation: `chat_full`** (1280px)
  - Used as: `t_chat_full` in URLs

- [x] **Strict Transformations status**: `ON`
  - Where to find: Settings → Security → Strict Transformations
  - Current status: [x] ON / [ ] OFF
  - Strict transformations is enabled in account. All delivery URLs must strictly use `t_<transformation_name>` and no ad-hoc transformation parameters.

- [x] **Upload response `public_id` format**
  - Confirmed sample: `main-sample` (from `https://res.cloudinary.com/dj4miyael/image/upload/v1755351192/main-sample.png`).
  - Storage: Exact `public_id` string stored in `MediaRef.key`. Delivery URLs: `https://res.cloudinary.com/dj4miyael/image/upload/t_{variant}/{public_id}`.

---

## Console Settings Confirmed

- [x] All three presets (`pc_avatar`, `pc_logo`, `pc_chat`) set to **Unsigned**
- [x] ZERO API keys or secrets in client code, repo, or logs
- [x] Strict Transformations: **ON** — codebase uses strictly `t_<name>` named transformations
- [x] Delivery URLs: Public CDN delivery without query string transforms

---

## Verification Checklist

- [x] `avatar_sm` (64px) & `avatar_lg` (256px) configured in `PcAvatar` and `MediaService`
- [x] `logo_sm` (128px) & `logo_lg` (512px) configured in `PcLogo` and `MediaService`
- [x] `chat_thumb` (480px) & `chat_full` (1280px) configured in `ImageBubbleWidget` & `FullscreenImageViewer`
- [x] File size limit enforced client-side at 10 MB and in `firestore.rules` (10,485,760 bytes)
- [x] Firestore security rules enforce `isValidMediaRef` on users (`avatar`), firms (`logo`), and chat messages (`media`)
- [x] Dual-read / dual-write architecture maintains backward compatibility with legacy consumers
