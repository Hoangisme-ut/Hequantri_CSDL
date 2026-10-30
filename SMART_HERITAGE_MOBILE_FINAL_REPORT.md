# SMART HERITAGE MOBILE â€” BÃO CÃO NGHIá»†M THU & AUDIT CHáº¤T LÆ¯á»¢NG CUá»I CÃ™NG

**Dá»± Ã¡n:** Smart Heritage Mobile App
**Thá»i Ä‘iá»ƒm táº¡o:** 2026-10-29
**Branch:** `feature/mobile-artifact-ui-i18n` (chuyá»ƒn sang `feature/mobile-ui-ux-polish`)
**Má»¥c tiÃªu:** HoÃ n thiá»‡n toÃ n bá»™ UI/UX, chuáº©n hÃ³a Design System Material 3, báº£o toÃ n nghiá»‡p vá»¥ xÃ¡c thá»±c vÃ  Ä‘iá»u hÆ°á»›ng, kiá»ƒm tra cháº¥t lÆ°á»£ng code trÆ°á»›c khi commit/push.

---

## 1. Káº¿t Quáº£ Kiá»ƒm Thá»­ Thá»±c Táº¿ (Code Quality & Verification)

| CÃ´ng cá»¥ kiá»ƒm tra | Lá»‡nh thá»±c hiá»‡n | Káº¿t quáº£ thá»±c táº¿ | Tráº¡ng thÃ¡i |
| :--- | :--- | :--- | :--- |
| **Dart Format** | `dart format --output=none --set-exit-if-changed lib test` | `Formatted 30 files (0 changed) in 0.37s` | **PASS (Clean)** |
| **Flutter Analyze** | `flutter analyze` | `Analyzing mobile_app... No issues found! (ran in 3.5s)` | **PASS (0 issue)** |
| **Flutter Widget & UI Tests** | `flutter test` | `All tests passed! (37/37 tests passed in 6.0s)` | **PASS (37/37)** |
| **Auth Service Unit Tests** | `flutter test test/auth_service_test.dart` | `All tests passed! (10/10 tests passed in 1.0s)` | **PASS (10/10)** |
| **Git Diff Syntax & Whitespace** | `git diff --check` | KhÃ´ng cÃ³ trailing whitespace, khÃ´ng conflict marker | **PASS (Clean)** |

---

## 2. Danh SÃ¡ch CÃ´ng Viá»‡c ÄÃ£ HoÃ n ThÃ nh (Completed)

### A. Chuáº©n hÃ³a Theme & Design System (Material 3)
- Chuáº©n hÃ³a toÃ n bá»™ báº£ng mÃ u `HeritagePalette`: `primaryNavy` (`#1E2A5A`), `actionBlue` (`#384CCA`), `lavender` (`#8B7CFF`), `background` (`#F1F5F9`), `surface` (`#FFFFFF`).
- Thay tháº¿ triá»‡t Ä‘á»ƒ cÃ¡c mÃ£ mÃ u hex hard-code vÃ  `Colors.white` táº¡i cÃ¡c trang con báº±ng token ngá»¯ nghÄ©a `theme.colorScheme.surface`, `HeritagePalette.*`.
- Chuáº©n hÃ³a bo gÃ³c (`AppRadii.small`, `AppRadii.medium`, `AppRadii.large`, `AppRadii.pill`) vÃ  khoáº£ng cÃ¡ch (`AppSpacing`).
- Loáº¡i bá» `BottomNavigationBar` kiá»ƒu cÅ©, thay tháº¿ báº±ng Material 3 `NavigationBar` vá»›i `indicatorColor` vÃ  nhÃ£n hiá»ƒn thá»‹ trá»±c quan 5 tab.

### B. Khá»Ÿi Ä‘á»™ng, Welcome & Onboarding
- HoÃ n thiá»‡n 3 slide giá»›i thiá»‡u di tÃ­ch lá»‹ch sá»­ tiÃªu biá»ƒu (VÄƒn Miáº¿u â€“ Quá»‘c Tá»­ GiÃ¡m, Phá»‘ cá»• Há»™i An, Cá»‘ Ä‘Ã´ Huáº¿).
- Bá»‘ cá»¥c responsive tÆ°Æ¡ng thÃ­ch má»i kÃ­ch thÆ°á»›c mÃ n hÃ¬nh tá»« 320px Ä‘áº¿n 430px vÃ  mÃ¡y tÃ­nh Ä‘á»ƒ bÃ n, khÃ´ng bá»‹ trÃ n dÃ²ng hay chá»“ng láº¥n chá»¯.
- Há»— trá»£ chuyá»ƒn Ä‘á»•i nhanh ngÃ´n ngá»¯ (VI/EN) vÃ  nÃºt "Bá» qua" / "Tiáº¿p tá»¥c" / "Báº¯t Ä‘áº§u khÃ¡m phÃ¡" rÃµ rÃ ng.

### C. XÃ¡c thá»±c tÃ i khoáº£n (Auth Flow)
- **ÄÄƒng nháº­p (Login):**
  - XÃ¡c thá»±c form cháº·t cháº½ (email RFC format, password báº¯t buá»™c).
  - Káº¿t ná»‘i tháº­t vá»›i `AuthService` qua OAuth2 Password flow; nháº­n vÃ  lÆ°u trá»¯ JWT `AuthToken`.
  - Xá»­ lÃ½ lá»—i API thÃ¢n thiá»‡n, khÃ´ng lÃ m sáº­p giao diá»‡n, khÃ´ng lá»™ thÃ´ng tin nháº¡y cáº£m.
  - PhÃ¢n tÃ¡ch ráº¡ch rÃ²i cháº¿ Ä‘á»™ "KhÃ¡m phÃ¡ Demo" vÃ  Ä‘Äƒng nháº­p tháº­t.
- **ÄÄƒng kÃ½ (Signup):**
  - Kiá»ƒm tra Ä‘á»™ dÃ i máº­t kháº©u tá»‘i thiá»ƒu 8 kÃ½ tá»±, xÃ¡c nháº­n máº­t kháº©u khá»›p.
  - Checkbox báº¯t buá»™c Ä‘á»“ng Ã½ vá»›i Äiá»u khoáº£n sá»­ dá»¥ng vÃ  ChÃ­nh sÃ¡ch báº£o máº­t.
  - NÃºt Submit hiá»ƒn thá»‹ tráº¡ng thÃ¡i `isLoading` Ä‘á»“ng bá»™, cháº·n gá»­i yÃªu cáº§u láº·p láº¡i.
- **QuÃªn máº­t kháº©u (Forgot Password):**
  - Giao diá»‡n nháº­p email khÃ´i phá»¥c tÃ i khoáº£n, bÃ¡o lá»—i káº¿t ná»‘i rÃµ rÃ ng náº¿u backend chÆ°a kÃ­ch hoáº¡t dá»‹ch vá»¥ gá»­i mail.

### D. CÃ¡c mÃ n hÃ¬nh chá»©c nÄƒng sau Ä‘Äƒng nháº­p
- **Trang chá»§ (Home):**
  - Thanh tÃ¬m kiáº¿m di sáº£n chuáº©n Material 3.
  - Hero banner khÃ¡m phÃ¡ cÃ´ng nghá»‡ iBeacon Smart Tour vá»›i hÃ¬nh ná»n phá»§ má» sang trá»ng.
  - Danh sÃ¡ch cuá»™n ngang di tÃ­ch ná»•i báº­t (`mockLocations`) vÃ  danh sÃ¡ch dá»c hiá»‡n váº­t tiÃªu biá»ƒu (`sampleArtifacts`).
- **Báº£n Ä‘á»“ di sáº£n (Map):**
  - Bá»‘ cá»¥c sáºµn sÃ ng tÃ­ch há»£p SDK Mapbox / Google Maps API.
  - Drawer di tÃ­ch gáº§n báº¡n vá»›i nhÃ£n khoáº£ng cÃ¡ch Ä‘a ngÃ´n ngá»¯ ("CÃ¡ch 0.8 km" / "0.8 km away").
- **Danh sÃ¡ch hiá»‡n váº­t (Artifacts):**
  - TÃ¬m kiáº¿m tá»©c thÃ¬ theo tá»« khÃ³a vÃ  bá»™ lá»c phÃ¢n loáº¡i chip (Äá»“ gá»‘m, Kim loáº¡i, VÄƒn hÃ³a, TÆ°á»£ng Ä‘iÃªu kháº¯c).
  - Tráº¡ng thÃ¡i empty state Ä‘áº¹p máº¯t khi khÃ´ng tÃ¬m tháº¥y káº¿t quáº£.
  - Icon yÃªu thÃ­ch dáº¡ng indicator trá»±c quan.
- **Chi tiáº¿t hiá»‡n váº­t (Artifact Detail):**
  - Hero image cÃ³ nÃºt Back vÃ  Favorite dáº¡ng ná»•i trÃ²n.
  - TrÃ¬nh phÃ¡t thuyáº¿t minh AI iBeacon Audio Guide mÃ´ phá»ng vá»›i thanh tiáº¿n trÃ¬nh hoáº¡t áº£nh mÆ°á»£t mÃ .
  - Bá»• sung `errorBuilder` cho hÃ¬nh áº£nh máº¡ng, chá»‘ng vá»¡ khung khi máº¥t máº¡ng.
- **YÃªu thÃ­ch (Favorites):**
  - Äáº¿m chÃ­nh xÃ¡c sá»‘ lÆ°á»£ng hiá»‡n váº­t vÃ  Ä‘á»‹a Ä‘iá»ƒm trÃªn tá»«ng tab (`All`, `Artifacts`, `Locations`).
  - Hiá»ƒn thá»‹ danh sÃ¡ch yÃªu thÃ­ch vÃ  empty state khi chÆ°a lÆ°u má»¥c nÃ o.
- **Lá»‹ch sá»­ tham quan (History):**
  - Bá»™ lá»c sáº¯p xáº¿p danh sÃ¡ch (`Táº¥t cáº£`, `Xem nhiá»u`, `Gáº§n Ä‘Ã¢y`).
  - Ghi nháº­n thá»i gian xem chi tiáº¿t.
- **CÃ¡ nhÃ¢n & CÃ i Ä‘áº·t (Profile & Settings):**
  - Bottom sheet chuyá»ƒn Ä‘á»•i ngÃ´n ngá»¯ Vi/En tá»©c thÃ¬.
  - Modal xÃ¡c nháº­n Ä‘Äƒng xuáº¥t vá»›i nÃºt mÃ u Ä‘á» `Color(0xFFEF4444)` dÃ nh riÃªng cho thao tÃ¡c quan trá»ng.

---

## 3. CÃ¡c TÃ­nh NÄƒng ChÆ°a HoÃ n ThÃ nh / Phá»¥ Thuá»™c Backend (Pending Backend)

1. **Backend Password Reset / Email Verification:**
   - Endpoint gá»­i email Ä‘áº·t láº¡i máº­t kháº©u cáº§n dá»‹ch vá»¥ SMTP / SES trÃªn server. Client Ä‘Ã£ sáºµn sÃ ng API contract.
2. **Social Login (Google / Apple Sign-in):**
   - Äang hiá»ƒn thá»‹ thÃ´ng bÃ¡o "ChÆ°a cáº¥u hÃ¬nh", cáº§n thÃªm Client ID vÃ  SHA-1 fingerprint trÃªn Google Cloud Console khi triá»ƒn khai production.
3. **Báº£n Ä‘á»“ thá»i gian thá»±c (Live GPS / Map SDK):**
   - Äang dÃ¹ng canvas mÃ´ phá»ng tÆ°Æ¡ng tÃ¡c; sáºµn sÃ ng cáº¯m Mapbox SDK hoáº·c Google Maps SDK.

---

## 4. Báº£ng Tá»•ng Há»£p Kiá»ƒm Thá»­ (Tested vs Not Tested)

| Háº¡ng má»¥c | PhÆ°Æ¡ng phÃ¡p kiá»ƒm thá»­ | Káº¿t quáº£ |
| :--- | :--- | :--- |
| **Welcome Flow** | Automated Widget Test (`widget_test.dart`) | ÄÃ£ pass 100% |
| **Login Validation** | Automated Widget Test (`auth_pages_test.dart`) | ÄÃ£ pass 100% |
| **Signup Validation** | Automated Widget Test (`auth_pages_test.dart`) | ÄÃ£ pass 100% |
| **Responsive Viewports (320px, 360px, 390px, Desktop)** | Automated Layout Tests | ÄÃ£ pass, 0 overflow |
| **Auth API Error Handling** | Unit Test Mock HttpClient (`auth_service_test.dart`) | ÄÃ£ pass 10/10 test |
| **Theme & Dark Mode** | Widget Theme Verification | ÄÃ£ pass |
| **iBeacon Scan & Suppression** | Widget Simulation Test | ÄÃ£ pass |
| **iBeacon Hardware Bluetooth tháº­t** | Manual Device Test | ChÆ°a kiá»ƒm thá»­ (cáº§n thiáº¿t bá»‹ pháº§n cá»©ng tháº­t) |
| **Production API Backend live** | Network Integration Test | Phá»¥ thuá»™c vÃ o mÃ´i trÆ°á»ng mÃ¡y chá»§ |

---

## 5. Khuyáº¿n Nghá»‹ Review TrÆ°á»›c Khi Push

- Review láº¡i cÃ¡c tá»‡p Ä‘Æ°á»£c stage trong commit.
- Cháº¡y á»©ng dá»¥ng trÃªn thiáº¿t bá»‹ tháº­t hoáº·c emulator Ä‘á»ƒ tráº£i nghiá»‡m animation mÆ°á»£t mÃ  cá»§a thanh Ä‘iá»u hÆ°á»›ng NavigationBar.
