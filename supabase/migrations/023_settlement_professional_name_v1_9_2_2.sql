-- ============================================================
-- FIXIS PRO v1.9.2.2
-- MIGRATION 023
-- Settlement Professional Name Snapshot
-- ============================================================
-- Objetivo:
--   - Mostrar nombre humano del profesional en liquidaciones.
--   - Mantener snapshot histórico del nombre al crear la liquidación.
--   - Evitar ampliar SELECT directo de profiles para Admin.
-- ============================================================

BEGIN;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS professional_name text;

-- Backfill de liquidaciones existentes.
UPDATE public.settlements s
SET professional_name = COALESCE(
    NULLIF(TRIM(p.full_name), ''),
    'Profesional FIXIS'
)
FROM public.profiles p
WHERE p.id = s.professional_id
  AND (
      s.professional_name IS NULL
      OR TRIM(s.professional_name) = ''
  );

-- Trigger para nuevas liquidaciones y cambios de professional_id.
CREATE OR REPLACE FUNCTION public.set_settlement_professional_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_name text;
BEGIN
    IF NEW.professional_id IS NULL THEN
        NEW.professional_name := COALESCE(
            NULLIF(TRIM(NEW.professional_name), ''),
            'Profesional FIXIS'
        );
        RETURN NEW;
    END IF;

    SELECT NULLIF(TRIM(p.full_name), '')
    INTO v_name
    FROM public.profiles p
    WHERE p.id = NEW.professional_id;

    NEW.professional_name := COALESCE(
        v_name,
        NULLIF(TRIM(NEW.professional_name), ''),
        'Profesional FIXIS'
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_settlement_professional_name
ON public.settlements;

CREATE TRIGGER trg_settlement_professional_name
BEFORE INSERT OR UPDATE OF professional_id
ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.set_settlement_professional_name();

REVOKE EXECUTE
ON FUNCTION public.set_settlement_professional_name()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.set_settlement_professional_name()
TO postgres, service_role;

COMMIT;
