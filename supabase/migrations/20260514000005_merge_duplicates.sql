-- Merge duplicate companies and clean empty shells
-- This is a one-time data migration

DO $$
DECLARE
  tbl text;
BEGIN
  -- ========================================================================
  -- 1. ESTUDIOS DOBLE V: merge [12] → [6]
  -- ========================================================================
  UPDATE catalogo SET cia = 6 WHERE cia = 12;
  UPDATE concepto SET cia = 6 WHERE cia = 12;
  UPDATE diario SET cia = 6 WHERE cia = 12;
  UPDATE fecha_s SET cia = 6 WHERE cia = 12;
  UPDATE saldo_ant SET cia = 6 WHERE cia = 12;
  UPDATE estado_r SET cia = 6 WHERE cia = 12;
  UPDATE plantilla_h SET cia = 6 WHERE cia = 12;
  UPDATE plantilla_d SET cia = 6 WHERE cia = 12;
  UPDATE company_members SET company_id = 6 WHERE company_id = 12;
  DELETE FROM cia WHERE id = 12;

  -- ========================================================================
  -- 2. IGLESIA BETHESDA: keep [14], merge any [13]/[15] data, delete shells
  -- ========================================================================
  UPDATE catalogo SET cia = 14 WHERE cia IN (13, 15);
  UPDATE concepto SET cia = 14 WHERE cia IN (13, 15);
  UPDATE diario SET cia = 14 WHERE cia IN (13, 15);
  UPDATE fecha_s SET cia = 14 WHERE cia IN (13, 15);
  UPDATE saldo_ant SET cia = 14 WHERE cia IN (13, 15);
  UPDATE estado_r SET cia = 14 WHERE cia IN (13, 15);
  UPDATE company_members SET company_id = 14 WHERE company_id IN (13, 15);
  DELETE FROM cia WHERE id IN (13, 15);

  -- ========================================================================
  -- 3. JUDA: merge [9] → [10]
  -- ========================================================================
  UPDATE catalogo SET cia = 10 WHERE cia = 9;
  UPDATE concepto SET cia = 10 WHERE cia = 9;
  UPDATE diario SET cia = 10 WHERE cia = 9;
  UPDATE fecha_s SET cia = 10 WHERE cia = 9;
  UPDATE saldo_ant SET cia = 10 WHERE cia = 9;
  UPDATE estado_r SET cia = 10 WHERE cia = 9;
  UPDATE company_members SET company_id = 10 WHERE company_id = 9;
  DELETE FROM cia WHERE id = 9;

  -- ========================================================================
  -- 4. ESTUDIOS DOBLE V (typo variant): delete empty shell
  -- ========================================================================
  DELETE FROM company_members WHERE company_id = 7;
  DELETE FROM cia WHERE id = 7;

  -- ========================================================================
  -- 5. Delete other empty shells (no data in any table)
  -- ========================================================================
  DELETE FROM company_members WHERE company_id IN (2, 5, 16, 17, 18);
  DELETE FROM cia WHERE id IN (2, 5, 16, 17, 18);

  -- ========================================================================
  -- 6. Reseed company serial to avoid gaps
  -- ========================================================================
  PERFORM setval('cia_id_seq', (SELECT max(id) FROM cia));
END;
$$;
