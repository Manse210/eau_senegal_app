-- ==============================================================
--  MIGRATION : Notifications Push (FCM)
--  Exécuter dans le SQL Editor Supabase
-- ==============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;
