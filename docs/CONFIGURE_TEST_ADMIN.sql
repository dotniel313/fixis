-- FIXIS PRO v1.9.1
-- CONVERTIR UN USUARIO EXISTENTE EN ADMIN DE PRUEBA
-- Ejecutar desde SQL Editor después de reemplazar EL_EMAIL_ADMIN.

SELECT id, email, role, account_status
FROM public.profiles
WHERE lower(email) = lower('EL_EMAIL_ADMIN');

-- Cuando confirmes que es el usuario correcto:
--
-- UPDATE public.profiles
-- SET
--   role = 'admin',
--   verification_status = 'approved',
--   account_status = 'active'
-- WHERE lower(email) = lower('EL_EMAIL_ADMIN');
--
-- Revisa:
--
-- SELECT id, email, role, verification_status, account_status
-- FROM public.profiles
-- WHERE lower(email) = lower('EL_EMAIL_ADMIN');
