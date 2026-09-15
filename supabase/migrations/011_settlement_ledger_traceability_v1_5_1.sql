BEGIN;

-- ============================================================
-- FIXIS PRO v1.5.1
-- MIGRATION 011
-- SETTLEMENT LEDGER TRACEABILITY PATCH
-- ============================================================
-- A settlement can aggregate earnings from multiple jobs.
-- Therefore settlement_debit must point to settlement_id rather
-- than incorrectly inheriting a single job/snapshot reference.
-- ============================================================

ALTER TABLE public.financial_ledger_entries
ADD COLUMN IF NOT EXISTS settlement_id uuid;

ALTER TABLE public.financial_ledger_entries
DROP CONSTRAINT IF EXISTS financial_ledger_entries_settlement_fk;

ALTER TABLE public.financial_ledger_entries
ADD CONSTRAINT financial_ledger_entries_settlement_fk
FOREIGN KEY (settlement_id)
REFERENCES public.settlements(id)
ON DELETE RESTRICT;

ALTER TABLE public.financial_ledger_entries
ALTER COLUMN job_id DROP NOT NULL;

ALTER TABLE public.financial_ledger_entries
ALTER COLUMN snapshot_id DROP NOT NULL;

ALTER TABLE public.financial_ledger_entries
DROP CONSTRAINT IF EXISTS ledger_source_integrity_check;

ALTER TABLE public.financial_ledger_entries
ADD CONSTRAINT ledger_source_integrity_check
CHECK (
    (
        entry_type IN ('professional_earning', 'platform_commission')
        AND job_id IS NOT NULL
        AND snapshot_id IS NOT NULL
        AND settlement_id IS NULL
    )
    OR
    (
        entry_type = 'settlement_debit'
        AND settlement_id IS NOT NULL
    )
    OR
    (
        entry_type = 'reversal'
    )
);

CREATE INDEX IF NOT EXISTS idx_ledger_settlement
ON public.financial_ledger_entries(settlement_id);

CREATE OR REPLACE FUNCTION public.mark_settlement_paid_trusted(
    p_settlement_id uuid
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_settlement public.settlements;
BEGIN
    SELECT *
    INTO v_settlement
    FROM public.settlements
    WHERE id = p_settlement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;

    IF v_settlement.status = 'paid' THEN
        RETURN v_settlement;
    END IF;

    IF v_settlement.status NOT IN ('requested', 'processing') THEN
        RAISE EXCEPTION 'INVALID_SETTLEMENT_STATE';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.settlement_items si
        WHERE si.settlement_id = v_settlement.id
    ) THEN
        RAISE EXCEPTION 'SETTLEMENT_ITEMS_REQUIRED';
    END IF;

    INSERT INTO public.financial_ledger_entries (
        account_id,
        job_id,
        snapshot_id,
        settlement_id,
        entry_type,
        direction,
        amount,
        currency,
        status,
        description,
        idempotency_key,
        available_at,
        settled_at
    )
    VALUES (
        v_settlement.account_id,
        NULL,
        NULL,
        v_settlement.id,
        'settlement_debit',
        'debit',
        v_settlement.requested_amount,
        'USD',
        'settled',
        'Retiro pagado FIXIS',
        'SETTLEMENT:' || v_settlement.id::text || ':DEBIT',
        now(),
        now()
    )
    ON CONFLICT (idempotency_key)
    DO NOTHING;

    UPDATE public.settlements
    SET
        status = 'paid',
        paid_at = COALESCE(paid_at, now())
    WHERE id = p_settlement_id
    RETURNING *
    INTO v_settlement;

    RETURN v_settlement;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.mark_settlement_paid_trusted(uuid)
FROM PUBLIC, anon, authenticated;

COMMIT;
