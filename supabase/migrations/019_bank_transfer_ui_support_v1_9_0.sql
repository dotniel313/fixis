BEGIN;

-- ============================================================
-- FIXIS PRO v1.9.0
-- MIGRATION 019
-- BANK TRANSFER UI SUPPORT
-- ============================================================
-- 1. Cuenta(s) bancaria(s) de FIXIS configurables desde backend.
-- 2. Bucket PRIVADO para comprobantes.
-- 3. El cliente solo puede subir/leer comprobantes de SUS pagos.
-- 4. Un archivo subido NO confirma un pago.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_bank_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    country_code text NOT NULL DEFAULT 'EC',
    currency text NOT NULL DEFAULT 'USD',

    bank_name text NOT NULL,
    account_type text NOT NULL,
    account_number text NOT NULL,

    beneficiary_name text NOT NULL,
    beneficiary_id text,

    instructions text,

    priority integer NOT NULL DEFAULT 100,
    is_active boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),

    CONSTRAINT payment_bank_accounts_country_check
        CHECK (country_code = 'EC'),

    CONSTRAINT payment_bank_accounts_currency_check
        CHECK (currency = 'USD'),

    CONSTRAINT payment_bank_accounts_type_check
        CHECK (account_type IN ('checking', 'savings')),

    CONSTRAINT payment_bank_accounts_priority_check
        CHECK (priority >= 0),

    CONSTRAINT payment_bank_accounts_required_text_check
        CHECK (
            length(trim(bank_name)) > 0
            AND length(trim(account_number)) > 0
            AND length(trim(beneficiary_name)) > 0
        )
);

CREATE INDEX IF NOT EXISTS idx_payment_bank_accounts_active_priority
ON public.payment_bank_accounts(is_active, priority, created_at);

ALTER TABLE public.payment_bank_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_bank_accounts_select_active
ON public.payment_bank_accounts;

CREATE POLICY payment_bank_accounts_select_active
ON public.payment_bank_accounts
FOR SELECT
TO authenticated
USING (is_active = true);

REVOKE ALL ON TABLE public.payment_bank_accounts
FROM anon, authenticated;

GRANT SELECT ON TABLE public.payment_bank_accounts
TO authenticated;


-- ============================================================
-- PRIVATE STORAGE BUCKET
-- ============================================================

INSERT INTO storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
VALUES (
    'payment-evidence',
    'payment-evidence',
    false,
    8388608,
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]::text[]
)
ON CONFLICT (id)
DO UPDATE SET
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;


-- Path convention:
--   <customer_uid>/<payment_id>/<timestamp>.<ext>
--
-- The policy verifies BOTH:
--   - first folder == auth.uid()
--   - second folder belongs to a payment owned by auth.uid()

DROP POLICY IF EXISTS payment_evidence_storage_insert_own
ON storage.objects;

CREATE POLICY payment_evidence_storage_insert_own
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'payment-evidence'
    AND array_length(storage.foldername(name), 1) >= 2
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND EXISTS (
        SELECT 1
        FROM public.payments p
        WHERE p.id::text = (storage.foldername(name))[2]
          AND p.customer_id = auth.uid()
          AND p.payment_method = 'bank_transfer'
          AND p.status IN (
              'pending_transfer',
              'voucher_uploaded',
              'pending_verification',
              'rejected'
          )
    )
);

DROP POLICY IF EXISTS payment_evidence_storage_select_own
ON storage.objects;

CREATE POLICY payment_evidence_storage_select_own
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'payment-evidence'
    AND array_length(storage.foldername(name), 1) >= 2
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND EXISTS (
        SELECT 1
        FROM public.payments p
        WHERE p.id::text = (storage.foldername(name))[2]
          AND p.customer_id = auth.uid()
    )
);

DROP POLICY IF EXISTS payment_evidence_storage_delete_own_unpaid
ON storage.objects;

CREATE POLICY payment_evidence_storage_delete_own_unpaid
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'payment-evidence'
    AND array_length(storage.foldername(name), 1) >= 2
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND EXISTS (
        SELECT 1
        FROM public.payments p
        WHERE p.id::text = (storage.foldername(name))[2]
          AND p.customer_id = auth.uid()
          AND p.status <> 'paid'
    )
);

COMMIT;
