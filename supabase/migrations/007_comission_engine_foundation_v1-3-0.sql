BEGIN;

-- ============================================================
-- FIXIS PRO v1.3.0
-- MIGRATION 007
-- COMMISSION ENGINE FOUNDATION
-- ============================================================


-- ============================================================
-- 1. REGLAS DE COMISIÓN
-- ============================================================

CREATE TABLE IF NOT EXISTS public.commission_rules (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    code text NOT NULL UNIQUE,

    name text NOT NULL,

    basis text NOT NULL,

    rate_percent numeric(5,2) NOT NULL,

    minimum_commission numeric(12,2),

    maximum_commission numeric(12,2),

    active boolean NOT NULL DEFAULT false,

    effective_from timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    effective_to timestamptz,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT commission_rules_basis_check
    CHECK (
        basis IN (
            'labor',
            'total'
        )
    ),


    CONSTRAINT commission_rules_rate_check
    CHECK (
        rate_percent >= 0
        AND rate_percent <= 100
    ),


    CONSTRAINT commission_rules_minimum_check
    CHECK (
        minimum_commission IS NULL
        OR minimum_commission >= 0
    ),


    CONSTRAINT commission_rules_maximum_check
    CHECK (
        maximum_commission IS NULL
        OR maximum_commission >= 0
    ),

    CONSTRAINT commission_rules_period_check
    CHECK (
        effective_to IS NULL
        OR effective_to > effective_from
    )
);


-- Solo una regla activa global en esta primera versión.
CREATE UNIQUE INDEX IF NOT EXISTS
idx_commission_rules_single_active
ON public.commission_rules ((active))
WHERE active = true;



-- ============================================================
-- 2. REGLA MVP
--
-- Hipótesis:
-- 15% exclusivamente sobre mano de obra.
-- ============================================================

INSERT INTO public.commission_rules (
    code,
    name,
    basis,
    rate_percent,
    minimum_commission,
    maximum_commission,
    active
)
VALUES (
    'FIXIS_MVP_15_LABOR',
    'FIXIS MVP 15% mano de obra',
    'labor',
    15.00,
    NULL,
    NULL,
    true
)
ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    basis = EXCLUDED.basis,
    rate_percent = EXCLUDED.rate_percent;



-- ============================================================
-- 3. SNAPSHOT ECONÓMICO
--
-- Una vez creada esta fila NO dependeremos de cambios futuros
-- en commission_rules.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.job_financial_snapshots (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id uuid NOT NULL UNIQUE,

    quote_id uuid NOT NULL UNIQUE,

    professional_id uuid NOT NULL,

    commission_rule_id uuid NOT NULL,

    commission_rule_code text NOT NULL,

    commission_basis text NOT NULL,

    labor_amount numeric(12,2) NOT NULL,

    materials_amount numeric(12,2) NOT NULL,

    other_amount numeric(12,2) NOT NULL,

    gross_amount numeric(12,2) NOT NULL,

    commission_basis_amount numeric(12,2) NOT NULL,

    commission_rate_percent numeric(5,2) NOT NULL,

    commission_amount numeric(12,2) NOT NULL,

    professional_amount numeric(12,2) NOT NULL,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT job_financial_snapshot_job_fk
    FOREIGN KEY (job_id)
    REFERENCES public.jobs(id)
    ON DELETE RESTRICT,


    CONSTRAINT job_financial_snapshot_quote_fk
    FOREIGN KEY (quote_id)
    REFERENCES public.quotes(id)
    ON DELETE RESTRICT,


    CONSTRAINT job_financial_snapshot_professional_fk
    FOREIGN KEY (professional_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,


    CONSTRAINT job_financial_snapshot_rule_fk
    FOREIGN KEY (commission_rule_id)
    REFERENCES public.commission_rules(id)
    ON DELETE RESTRICT,


    CONSTRAINT financial_snapshot_basis_check
    CHECK (
        commission_basis IN (
            'labor',
            'total'
        )
    ),


    CONSTRAINT financial_snapshot_amounts_check
    CHECK (
        labor_amount >= 0
        AND materials_amount >= 0
        AND other_amount >= 0
        AND gross_amount > 0
        AND commission_basis_amount >= 0
        AND commission_amount >= 0
        AND professional_amount >= 0
    )
);



CREATE INDEX IF NOT EXISTS
idx_financial_snapshots_professional_created
ON public.job_financial_snapshots(
    professional_id,
    created_at DESC
);



-- ============================================================
-- 4. RLS
-- ============================================================

ALTER TABLE public.commission_rules
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.job_financial_snapshots
ENABLE ROW LEVEL SECURITY;



-- ============================================================
-- 5. POLICIES
--
-- El FIXI puede leer su snapshot.
-- No puede crear ni alterar valores económicos.
-- ============================================================

DROP POLICY IF EXISTS
"financial_snapshots_select_own"
ON public.job_financial_snapshots;


CREATE POLICY "financial_snapshots_select_own"
ON public.job_financial_snapshots
FOR SELECT
TO authenticated
USING (
    professional_id = (
        SELECT auth.uid()
    )
);



-- Regla activa puede ser leída por authenticated.
DROP POLICY IF EXISTS
"commission_rules_select_active"
ON public.commission_rules;


CREATE POLICY "commission_rules_select_active"
ON public.commission_rules
FOR SELECT
TO authenticated
USING (
    active = true
);



-- ============================================================
-- 6. GRANTS
-- ============================================================

REVOKE ALL
ON public.commission_rules
FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON public.commission_rules
FROM authenticated;

GRANT SELECT
ON public.commission_rules
TO authenticated;



REVOKE ALL
ON public.job_financial_snapshots
FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON public.job_financial_snapshots
FROM authenticated;

GRANT SELECT
ON public.job_financial_snapshots
TO authenticated;



-- ============================================================
-- 7. FUNCIÓN INTERNA DE ACEPTACIÓN
--
-- NO se concede a authenticated.
-- Mientras jobs no tenga client_id, esta operación solo debe
-- ejecutarse desde backend/admin confiable.
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_quote_trusted(
    p_quote_id uuid
)
RETURNS public.job_financial_snapshots
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_quote public.quotes;
    v_job public.jobs;
    v_rule public.commission_rules;

    v_basis_amount numeric(12,2);
    v_commission numeric(12,2);
    v_professional_amount numeric(12,2);

    v_snapshot public.job_financial_snapshots;

BEGIN

    -- --------------------------------------------------------
    -- COTIZACIÓN
    -- --------------------------------------------------------

    SELECT *
    INTO v_quote
    FROM public.quotes
    WHERE id = p_quote_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_quote.status <> 'submitted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;



    -- --------------------------------------------------------
    -- JOB
    -- --------------------------------------------------------

    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = v_quote.job_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.status <> 'quote_submitted' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.assigned_pro_id IS DISTINCT FROM
       v_quote.professional_id
    THEN
        RAISE EXCEPTION 'QUOTE_PROFESSIONAL_MISMATCH';
    END IF;



    -- --------------------------------------------------------
    -- REGLA DE COMISIÓN
    -- --------------------------------------------------------

    SELECT *
    INTO v_rule
    FROM public.commission_rules
    WHERE active = true
      AND effective_from <= now()
      AND (
          effective_to IS NULL
          OR effective_to > now()
      )
    ORDER BY effective_from DESC
    LIMIT 1;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'NO_ACTIVE_COMMISSION_RULE';
    END IF;



    -- --------------------------------------------------------
    -- BASE COMISIONABLE
    -- --------------------------------------------------------

    IF v_rule.basis = 'labor' THEN

        v_basis_amount :=
            v_quote.labor_amount;

    ELSIF v_rule.basis = 'total' THEN

        v_basis_amount :=
            v_quote.total_amount;

    ELSE

        RAISE EXCEPTION 'INVALID_COMMISSION_BASIS';

    END IF;



    -- --------------------------------------------------------
    -- CALCULAR COMISIÓN
    -- --------------------------------------------------------

    v_commission :=
        ROUND(
            (
                v_basis_amount
                * v_rule.rate_percent
                / 100
            ),
            2
        );


    -- Mínimo opcional
    IF v_rule.minimum_commission IS NOT NULL THEN

        v_commission :=
            GREATEST(
                v_commission,
                v_rule.minimum_commission
            );

    END IF;


    -- Máximo opcional
    IF v_rule.maximum_commission IS NOT NULL THEN

        v_commission :=
            LEAST(
                v_commission,
                v_rule.maximum_commission
            );

    END IF;


    -- Nunca permitir comisión superior al total.
    v_commission :=
        LEAST(
            v_commission,
            v_quote.total_amount
        );


    v_professional_amount :=
        ROUND(
            v_quote.total_amount
            - v_commission,
            2
        );



    -- --------------------------------------------------------
    -- SNAPSHOT
    -- --------------------------------------------------------

    INSERT INTO public.job_financial_snapshots (

        job_id,

        quote_id,

        professional_id,

        commission_rule_id,

        commission_rule_code,

        commission_basis,

        labor_amount,

        materials_amount,

        other_amount,

        gross_amount,

        commission_basis_amount,

        commission_rate_percent,

        commission_amount,

        professional_amount

    )

    VALUES (

        v_job.id,

        v_quote.id,

        v_quote.professional_id,

        v_rule.id,

        v_rule.code,

        v_rule.basis,

        v_quote.labor_amount,

        v_quote.materials_amount,

        v_quote.other_amount,

        v_quote.total_amount,

        v_basis_amount,

        v_rule.rate_percent,

        v_commission,

        v_professional_amount

    )

    RETURNING *
    INTO v_snapshot;



    -- --------------------------------------------------------
    -- ACEPTAR QUOTE
    -- --------------------------------------------------------

    UPDATE public.quotes

    SET
        status = 'accepted',
        accepted_at = now()

    WHERE id = v_quote.id;



    -- --------------------------------------------------------
    -- AUTORIZAR JOB
    -- --------------------------------------------------------

    UPDATE public.jobs

    SET
        status = 'authorized',
        accepted_quote_id = v_quote.id

    WHERE id = v_job.id;



    RETURN v_snapshot;

END;
$$;



-- ============================================================
-- 8. NO EXPONER A CLIENTES TODAVÍA
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.accept_quote_trusted(uuid)
FROM PUBLIC, anon, authenticated;


COMMIT;