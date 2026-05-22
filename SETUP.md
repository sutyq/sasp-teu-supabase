# SASP TEU · Supabase Setup

Krok za krokem, jak rozjet aplikaci s cloudovou databází. **Doba: ~15 minut.**

---

## Co dostaneš na konci

- Aplikace běží jako statická HTML stránka (Netlify, GitHub Pages, vlastní web)
- Vozidla se ukládají do Supabase PostgreSQL databáze
- **Realtime sync** — když officer přidá auto, ostatní to vidí okamžitě bez F5
- **Officer login** — jen autorizovaní lidé můžou editovat, ostatní jen čtou
- **Image upload** — nahrávání obrázků přes Supabase Storage
- **Free tier**: 500 MB DB + 1 GB storage + 50K měsíčních active users → bohatě stačí

---

## Krok 1 — Založ Supabase projekt (3 min)

1. Jdi na [https://supabase.com](https://supabase.com) → **Start your project** → přihlas se přes GitHub nebo email
2. Klikni **New Project**
3. Vyplň:
   - **Name**: `sasp-teu` (nebo cokoli)
   - **Database Password**: vygeneruj silné heslo, **ulož si ho** (nepoužiješ ho každý den, ale je potřeba pro občasnou administraci)
   - **Region**: vyber nejbližší (Frankfurt pro CZ)
   - **Pricing Plan**: **Free**
4. Klikni **Create new project** a počkej ~2 minuty, než se to nastartuje

---

## Krok 2 — Spusť SQL scripty (2 min)

1. V Supabase otevři **SQL Editor** (ikona vlevo, vypadá jako papír s textem)
2. Klikni **New query**
3. Otevři soubor [`setup/01-schema.sql`](setup/01-schema.sql), zkopíruj **celý jeho obsah**
4. **Před spuštěním** najdi v něm tenhle řádek a změň email na svůj:

   ```sql
   values ('your-email@example.com', 'TEU Admin', true)
   ```

   Tohle bude první officer (admin). Použij stejný email, kterým se pak budeš přihlašovat.

5. Klikni **Run** (vpravo dole, nebo Ctrl+Enter)
6. Mělo by se objevit zelené `Success. No rows returned.` — vše OK

7. Otevři **New query** znovu
8. Zkopíruj obsah [`setup/02-seed.sql`](setup/02-seed.sql) a spusť ho
9. Hotovo — naseedoval jsi 57 vozidel

---

## Krok 3 — Získej API klíče (1 min)

1. V Supabase jdi do **Settings** (ozubené kolečko vlevo dole) → **API**
2. Najdi:
   - **Project URL** — vypadá jako `https://abcdefgh.supabase.co`
   - **Project API keys** → `anon` `public` — dlouhý JWT token začínající `eyJ...`
3. Zkopíruj obě hodnoty

---

## Krok 4 — Nastav config.js (30 s)

Otevři `config.js` v editoru a vlož hodnoty:

```js
window.SUPABASE_CONFIG = {
  SUPABASE_URL: 'https://abcdefgh.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  STORAGE_BUCKET: 'vehicles',
};
```

> **Pozn.:** Anon key je SAFE dát do veřejného JS kódu. Tomu je určený. Bezpečnost řeší Row-Level Security (RLS), kterou už máš nastavenou v SQL skriptu.

---

## Krok 5 — Vytvoř si účet (2 min)

1. Otevři `index.html` v prohlížeči (nebo přes `python3 -m http.server`)
2. Klikni vpravo nahoře **Officer login**
3. Klikni **Vytvořit nový účet →**
4. Vyplň svůj email (ten, který jsi dal do SQL skriptu) a heslo, klikni **Vytvořit účet**
5. Supabase ti pošle potvrzovací email (pokud je email confirmation zapnutý — ve Free tieru default ano)
6. Klikni na link v emailu pro potvrzení
7. Vrať se do aplikace, přihlas se

   Jak víš, že to funguje: vidíš zelený badge se svým emailem v headeru + tlačítko **+ Přidat** vlevo od něj.

> **Vypnutí email confirmation pro lokální testing:** v Supabase → Authentication → Settings → vypni **Enable email confirmations**. Pro produkci doporučuju nechat ZAPNUTÉ.

---

## Krok 6 — Přidávej další officery (po potřebě)

Když chceš dát přístup dalšímu člověku:

1. Pošli mu URL aplikace
2. Ať si vytvoří účet přes **Officer login → Vytvořit nový účet**
3. Ty (jako admin) otevři Supabase → **Table Editor** → tabulka `officers`
4. Klikni **+ Insert row**:
   - `email`: jeho email (přesně, malá písmena)
   - `display_name`: jak ho má zobrazovat header
   - `is_admin`: nech `false` (pokud nemá být admin)
5. Hotovo, hned jak se příště přihlásí, uvidí editor.

---

## Krok 7 — Nasaď to (volitelně)

Aplikace je statické HTML, nahrát jde kamkoli:

### Netlify (nejjednodušší)
1. Jdi na [netlify.com](https://netlify.com) → drag & drop celou složku `sasp-teu-supabase/` do dashboard
2. Dostaneš URL typu `random-name.netlify.app`
3. (Volitelně v settings → změň název na něco hezkého)

### GitHub Pages
1. Vytvoř GitHub repozitář, pushni tam celou složku
2. Settings → Pages → Source: `main` branch, root
3. Dostaneš URL `username.github.io/repo-name`

### Vlastní webhosting
Prostě nahrát všechno přes FTP. Stačí jakýkoli hosting co umí statické soubory.

---

## Časté problémy

**"Setup nedokončen" hláška**
→ `config.js` má pořád placeholdery. Vlož svoje SUPABASE_URL a anon key.

**Přihlašuji se, ale tlačítko "+ Přidat" se neobjeví**
→ Tvůj email není v tabulce `officers`. Otevři Supabase → Table Editor → `officers` → přidej řádek.

**"Failed to load vehicles"**
→ Spustil jsi 01-schema.sql? Zkontroluj Supabase → Table Editor → měla by tam být tabulka `vehicles`. Pokud ne, spusť skript znovu.

**Upload obrázku selže**
→ Ujisti se, že storage bucket `vehicles` existuje a je veřejný. V Supabase → Storage → měl by být bucket `vehicles` s ikonou globusu (public).

**Email confirmation zaseknutý**
→ V Supabase → Authentication → Users → najdi svůj záznam → klikni `...` → **Confirm user manually**. Případně v Settings → vypni email confirmation.

**Realtime se neaktualizuje**
→ Zkontroluj v 01-schema.sql poslední sekci `alter publication supabase_realtime add table vehicles;`. Pokud selhala, spusť ji ručně.

---

## Struktura projektu

```
sasp-teu-supabase/
├── index.html              ← aplikace (otevři tohle)
├── config.js               ← TVOJE Supabase údaje (vyplnit!)
├── vehicles/               ← výchozí obrázky (původních 57 vozidel)
├── setup/
│   ├── 01-schema.sql       ← spusť v Supabase SQL Editor (vytvoří tabulky)
│   └── 02-seed.sql         ← spusť v Supabase SQL Editor (naplní výchozí data)
└── SETUP.md                ← tenhle návod
```

---

## Pokročilé

### Změna výchozího obrázku vozidla
Když nahraješ nový obrázek přes editor, automaticky se uloží do Supabase Storage. Původní obrázky v `vehicles/` zůstávají jako fallback — pokud jsou v poli `image` v DB cesty typu `vehicles/t20.png`, načtou se relativně ze složky vedle `index.html`. Pokud je tam plná URL (https://...), použije se ta.

### Migrace dat
Export DB: Supabase → Table Editor → vehicles → ⋯ → Download CSV  
Import: SQL Editor → `COPY vehicles FROM STDIN CSV HEADER;` nebo jednoduše `INSERT` SQL.

### Resetování dat
Spusť v SQL Editoru: `TRUNCATE vehicles;` (smaže všechna vozidla — pozor!).  
Pak znovu `02-seed.sql` pro výchozích 57 vozů.
