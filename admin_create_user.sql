-- Supprime l'ancienne version si elle existe
DROP FUNCTION IF EXISTS public.admin_create_user;

-- Active pgcrypto (déjà présent dans Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Fonction pour créer un utilisateur (admin seulement)
CREATE OR REPLACE FUNCTION public.admin_create_user(
  p_email TEXT,
  p_password TEXT,
  p_role TEXT
) RETURNS JSONB
SECURITY DEFINER
SET search_path = extensions, public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  IF auth.jwt() -> 'user_metadata' ->> 'role' != 'admin' THEN
    RAISE EXCEPTION 'Seul un admin peut créer des utilisateurs';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'Cet email est déjà utilisé';
  END IF;

  v_user_id := gen_random_uuid();

  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token,
    aud, role
  ) VALUES (
    v_user_id, '00000000-0000-0000-0000-000000000000', p_email,
    crypt(p_password, gen_salt('bf')), NOW(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('role', p_role),
    NOW(), NOW(), '', '', '', '',
    'authenticated', 'authenticated'
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_user_id, v_user_id,
    jsonb_build_object('sub', v_user_id, 'email', p_email),
    'email', p_email, NOW(), NOW(), NOW()
  );

  EXECUTE format('INSERT INTO %I (id, email, role) VALUES ($1, $2, $3)', p_role)
    USING v_user_id, p_email, p_role;

  INSERT INTO public.profiles (id, nom, telephone, role)
    VALUES (v_user_id, p_email, '', p_role);

  RETURN jsonb_build_object('id', v_user_id, 'email', p_email, 'role', p_role);
END;
$$ LANGUAGE plpgsql;
