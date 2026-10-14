-- ═══════════════════════════════════════════════════════
--  ComFin — Setup de base de datos en Supabase
--  Ejecuta esto en el SQL Editor de tu proyecto Supabase
-- ═══════════════════════════════════════════════════════

-- 1. PROFILES (miembros de la comunidad)
CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  email        TEXT,
  role         TEXT NOT NULL DEFAULT 'miembro' CHECK (role IN ('admin','tesorero','miembro')),
  active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TRANSACCIONES
CREATE TABLE IF NOT EXISTS transactions (
  id           TEXT PRIMARY KEY,
  description  TEXT NOT NULL,
  amount       NUMERIC NOT NULL,
  date         DATE NOT NULL,
  cat          TEXT NOT NULL,
  method       TEXT,
  ref          TEXT,
  notes        TEXT,
  type         TEXT NOT NULL CHECK (type IN ('ingreso','gasto')),
  user_id      UUID,
  member_id    UUID,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ,
  updated_by   UUID
);

-- 3. CUOTAS (registro de pagos mensuales)
CREATE TABLE IF NOT EXISTS cuotas (
  cuota_key  TEXT PRIMARY KEY,   -- formato: "userId|YYYY-MM"
  user_id    UUID,
  tx_id      TEXT REFERENCES transactions(id) ON DELETE CASCADE,
  month_key  TEXT NOT NULL
);

-- 4. PRESUPUESTOS
CREATE TABLE IF NOT EXISTS budgets (
  cat     TEXT PRIMARY KEY,
  amount  NUMERIC NOT NULL
);

-- 5. CONFIGURACIÓN
CREATE TABLE IF NOT EXISTS app_config (
  id       INT PRIMARY KEY DEFAULT 1,
  name     TEXT DEFAULT 'Mi Comunidad',
  cuota    NUMERIC DEFAULT 50000,
  due_day  INT DEFAULT 10,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO app_config (id, name, cuota, due_day)
  VALUES (1, 'Mi Comunidad', 50000, 10)
  ON CONFLICT (id) DO NOTHING;

-- 6. AUDITORÍA
CREATE TABLE IF NOT EXISTS audit_log (
  id         TEXT PRIMARY KEY,
  ts         TIMESTAMPTZ DEFAULT NOW(),
  user_name  TEXT,
  user_id    UUID,
  action     TEXT NOT NULL,
  detail     TEXT
);

-- ═══════════════════════════════════════════════════════
--  ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════

ALTER TABLE profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuotas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets     ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log   ENABLE ROW LEVEL SECURITY;

-- Funciones helper (SECURITY DEFINER para evitar recursión en RLS)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin' AND active = TRUE
  )
$$;

CREATE OR REPLACE FUNCTION is_writer()
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','tesorero') AND active = TRUE
  )
$$;

-- PROFILES
CREATE POLICY "profiles_read"   ON profiles FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_insert_admin" ON profiles FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "profiles_update" ON profiles FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "profiles_delete" ON profiles FOR DELETE TO authenticated USING (is_admin());

-- TRANSACTIONS
CREATE POLICY "tx_read"   ON transactions FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "tx_insert" ON transactions FOR INSERT TO authenticated WITH CHECK (is_writer());
CREATE POLICY "tx_update" ON transactions FOR UPDATE TO authenticated USING (is_writer());
CREATE POLICY "tx_delete" ON transactions FOR DELETE TO authenticated USING (is_writer());

-- CUOTAS
CREATE POLICY "cuotas_read"  ON cuotas FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "cuotas_write" ON cuotas FOR ALL    TO authenticated USING (is_writer());

-- BUDGETS
CREATE POLICY "budgets_read"  ON budgets FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "budgets_write" ON budgets FOR ALL    TO authenticated USING (is_writer());

-- APP CONFIG
CREATE POLICY "config_read"   ON app_config FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "config_update" ON app_config FOR UPDATE TO authenticated USING (is_admin());

-- AUDIT LOG
CREATE POLICY "audit_read"   ON audit_log FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "audit_insert" ON audit_log FOR INSERT TO authenticated WITH CHECK (TRUE);
