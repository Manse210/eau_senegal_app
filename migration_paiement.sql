-- Ajouter les colonnes de paiement à la table commandes
ALTER TABLE public.commandes
  ADD COLUMN IF NOT EXISTS payment_method TEXT,
  ADD COLUMN IF NOT EXISTS payment_transaction_id TEXT;
