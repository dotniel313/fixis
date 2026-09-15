-- ============================================================
-- FIXIS PRO v1.9.0
-- CONFIGURAR CUENTA BANCARIA
-- EJECUTAR SOLO DESPUÉS DE REEMPLAZAR LOS PLACEHOLDERS.
-- ============================================================

-- Ejemplo:
--
-- INSERT INTO public.payment_bank_accounts (
--   bank_name,
--   account_type,
--   account_number,
--   beneficiary_name,
--   beneficiary_id,
--   instructions,
--   priority,
--   is_active
-- )
-- VALUES (
--   'NOMBRE DEL BANCO',
--   'checking', -- checking = corriente | savings = ahorros
--   'NUMERO_DE_CUENTA',
--   'RAZON SOCIAL / TITULAR FIXIS',
--   'RUC_O_IDENTIFICACION',
--   'Incluye la referencia FIX-... en el concepto de la transferencia.',
--   10,
--   true
-- );
--
-- Verificación:
SELECT
    id,
    bank_name,
    account_type,
    account_number,
    beneficiary_name,
    beneficiary_id,
    instructions,
    priority,
    is_active
FROM public.payment_bank_accounts
ORDER BY is_active DESC, priority ASC, created_at ASC;
