# Чек-лист запуска TWO SIDES

Всё, что в этом списке делается на сайте Roblox или в Studio руками. Код уже готов.

## 1. Публикация
- [ ] Studio: **File → Publish to Roblox** → новая игра «TWO SIDES — Duo Escape [2 PLAYER]».
- [ ] **Game Settings → Security → Enable Studio Access to API Services** (сохранения и рекорды в Studio).
- [ ] **Game Settings → Basic Info**: жанр Puzzle / Party & Casual, устройства — все (Phone, Tablet, Computer, Console).
- [ ] **Game Settings → Players**: Max players **20–24** (пары × 10–12), аватар R15.
- [ ] Заполнить **анкету Experience Guidelines** (Maturity) — без насилия → «Minimal».

## 2. Товары и пассы
В *Creator Dashboard → игра → Monetization* создать и вписать ID в `src/shared/EconomyConfig.luau`:

| Ключ | Тип | Цена |
|---|---|---|
| SkipRoom | Developer Product | 29 |
| Shards1000 / 5500 / 15000 / 40000 | Developer Product | 49 / 199 / 449 / 999 |
| SeasonPremium | Developer Product | 399 |
| SeasonPremiumPlus | Developer Product | 799 |
| SeasonLevel | Developer Product | 49 |
| DoubleShards | Game Pass | 199 |
| VIP | Game Pass | 299 |

Иконки товаров — из `assets/icons/` (осколок, яйцо, «пропустить» и т.д.) или свои.

## 3. Страница игры
- [ ] Иконка: `assets/branding/game-icon-512.png` (временная — заменить на арт с питомцами).
- [ ] 3–5 превью 1920×1080: `assets/branding/thumbnail-1920x1080.png` + скриншоты комнат с двумя мирами.
- [ ] Описание (пример):
  > Ты и напарник — в одном здании, но в РАЗНЫХ мирах. Плита одного открывает дверь другому,
  > код видит один — вводит другой. Договоритесь, найдите отличия и выберитесь вместе!
  > Собирай питомцев, проходи сезонный пропуск, ставь рекорды с друзьями.
- [ ] Включить **A/B-тест иконок и превью** (Creator Dashboard → Experience → Thumbnails/Icon experiments).
- [ ] Загрузить атлас иконок `assets/icons-sheet.png` и вписать ID в `src/shared/Icons.luau`.

## 4. Тест перед запуском
- [ ] Studio: Test → 2 Players — пройти главу вдвоём, ежедневную комнату, открыть яйцо.
- [ ] Проверить на телефоне (Studio → Device Emulator → iPhone / Android) — кнопки не перекрываются.
- [ ] Закрытый тест на 20–50 человек (друзья, Discord): собрать отзывы, где застревают.
- [ ] Посмотреть **Analytics → Funnels / Onboarding**: на каком шаге уходят новички.

## 5. Мягкий запуск
- [ ] Открыть игру (Public).
- [ ] Небольшой бюджет на **Sponsored Experiences** (Ads Manager) — 3–7 дней, смотреть CTR иконки.
- [ ] Следить за метриками: D1 ≥ 25%, D7 ≥ 8%, сессия ≥ 20 мин, платящие 2–4%.
- [ ] Каждые 2 недели — новые комнаты/ивент; каждые 6 недель — новая глава и пропуск
  (`SeasonConfig.luau`: новый `Id`, даты, награды).

## Аналитика, которую пишет игра
| Где смотреть | Что |
|---|---|
| Analytics → Onboarding | Joined → TutorialClosed → FirstSession → FirstRoomCompleted → FirstChapterCompleted |
| Analytics → Funnels → Chapter1 | на какой комнате бросают главу |
| Analytics → Economy (Shards) | откуда приходят и куда тратятся осколки |
| Analytics → Custom events | Purchase_*, PassLevel, ChapterTime |
