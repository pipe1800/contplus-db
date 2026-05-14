-- Migrate: Run initial mayorización from imported journal entries
-- This processes all months and computes account balances including hierarchy

DO $$
DECLARE
  v_level int;
  v_max_level int;
BEGIN
  -- Clear existing
  DELETE FROM saldos WHERE cia = 20;

  -- Step 1: Direct aggregation from journal entries to leaf accounts
  INSERT INTO saldos (cuenta, cargo, abono, sald_mes, fecha, cia)
  SELECT 
    c.cuenta,
    COALESCE(dr.cargo, 0),
    COALESCE(dr.abono, 0),
    0,
    c.fecha_ini,
    c.cia
  FROM catalogo c
  LEFT JOIN (
    SELECT cuenta, SUM(cargo) as cargo, SUM(abono) as abono, mes
    FROM diario 
    WHERE cia = 20
    GROUP BY cuenta, mes
  ) dr ON c.cuenta = dr.cuenta 
    AND EXTRACT(YEAR FROM c.fecha_ini) = EXTRACT(YEAR FROM dr.mes)
    AND EXTRACT(MONTH FROM c.fecha_ini) = EXTRACT(MONTH FROM dr.mes)
  WHERE c.cia = 20;

  -- Step 2: Set running balance for leaf accounts
  UPDATE saldos s SET sald_mes = 
    CASE WHEN c.tipo IN ('A','E','R','O') THEN s.cargo - s.abono
         ELSE s.abono - s.cargo
    END
  FROM catalogo c
  WHERE s.cia = c.cia 
    AND s.cuenta = c.cuenta 
    AND s.fecha = c.fecha_ini
    AND s.cia = 20;

  -- Step 3: Propagate to parent accounts (bottom-up by level)
  SELECT COALESCE(MAX(nivel), 0) INTO v_max_level FROM catalogo WHERE cia = 20;
  
  FOR v_level IN REVERSE v_max_level..1 LOOP
    INSERT INTO saldos (cuenta, cargo, abono, sald_mes, fecha, cia)
    SELECT 
      p.cuenta,
      COALESCE(SUM(s.cargo), 0),
      COALESCE(SUM(s.abono), 0),
      0,
      s.fecha,
      s.cia
    FROM saldos s
    JOIN catalogo c ON s.cia = c.cia AND s.cuenta = c.cuenta AND s.fecha = c.fecha_ini
    JOIN catalogo p ON c.cia = p.cia AND c.cuentd = p.cuenta AND c.fecha_ini = p.fecha_ini
    WHERE s.cia = 20 AND c.nivel = v_level AND p.nivel = v_level - 1
    GROUP BY p.cuenta, s.fecha, s.cia
    ON CONFLICT (cia, cuenta, fecha) DO UPDATE
    SET cargo = saldos.cargo + EXCLUDED.cargo,
        abono = saldos.abono + EXCLUDED.abono;
  END LOOP;

  -- Step 4: Update parent balances
  UPDATE saldos s SET sald_mes = 
    CASE WHEN c.tipo IN ('A','E','R','O') THEN s.cargo - s.abono
         ELSE s.abono - s.cargo
    END
  FROM catalogo c
  WHERE s.cia = c.cia 
    AND s.cuenta = c.cuenta 
    AND s.fecha = c.fecha_ini
    AND s.cia = 20;
END;
$$;
