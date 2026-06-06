-- ==============================================================
--  MIGRATION : Certification Fournisseurs + Évaluation Livreurs
--  À exécuter DANS LE SQL EDITOR du dashboard Supabase
-- ==============================================================

-- 1. AJOUT COLONNE certifie DANS fournisseur
ALTER TABLE public.fournisseur
  ADD COLUMN IF NOT EXISTS certifie BOOLEAN DEFAULT false;

-- 2. TABLE evaluations_livreurs
CREATE TABLE IF NOT EXISTS public.evaluations_livreurs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  livreur_id UUID NOT NULL REFERENCES public.livreur(id) ON DELETE CASCADE,
  commande_id UUID NOT NULL REFERENCES public.commandes(id) ON DELETE CASCADE,
  note INTEGER NOT NULL CHECK (note >= 1 AND note <= 5),
  commentaire TEXT,
  evaluateur_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(commande_id)
);

-- Ajout colonne note_moyenne dans livreur (pour classement)
ALTER TABLE public.livreur
  ADD COLUMN IF NOT EXISTS note_moyenne DECIMAL(2,1) DEFAULT 0.0;

-- 3. INDEX pour performances
CREATE INDEX IF NOT EXISTS idx_eval_livreur_id ON public.evaluations_livreurs(livreur_id);
CREATE INDEX IF NOT EXISTS idx_eval_note ON public.evaluations_livreurs(note);

-- ==============================================================
--  RLS POLICIES
-- ==============================================================

-- Activer RLS sur evaluations_livreurs
ALTER TABLE public.evaluations_livreurs ENABLE ROW LEVEL SECURITY;

-- Suppression des anciennes policies (pour mise à jour)
DROP POLICY IF EXISTS "Insertion evaluation par boutiquier" ON public.evaluations_livreurs;
DROP POLICY IF EXISTS "Lecture evaluation par fournisseur" ON public.evaluations_livreurs;
DROP POLICY IF EXISTS "Lecture evaluation par admin" ON public.evaluations_livreurs;
DROP POLICY IF EXISTS "Admin full access evaluations" ON public.evaluations_livreurs;

-- Un boutiquier peut créer une évaluation pour une de ses commandes
CREATE POLICY "Insertion evaluation par boutiquier" ON public.evaluations_livreurs
  FOR INSERT WITH CHECK (
    auth.jwt() -> 'user_metadata' ->> 'role' = 'boutiquier'
    AND EXISTS (
      SELECT 1 FROM public.commandes
      WHERE commandes.id = commande_id
      AND commandes.boutiquier_id = auth.uid()
    )
  );

-- Tout le monde connecté peut lire les évaluations (pour affichage notes)
CREATE POLICY "Lecture publique evaluations" ON public.evaluations_livreurs
  FOR SELECT USING (auth.role() = 'authenticated');

-- Admin full access
CREATE POLICY "Admin full access evaluations" ON public.evaluations_livreurs
  FOR ALL USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');

-- ==============================================================
--  FONCTION DE MISE À JOUR note_moyenne (déclencheur automatique)
-- ==============================================================

CREATE OR REPLACE FUNCTION public.update_livreur_note_moyenne()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.livreur
  SET note_moyenne = (
    SELECT ROUND(COALESCE(AVG(note), 0)::numeric, 1)
    FROM public.evaluations_livreurs
    WHERE livreur_id = NEW.livreur_id
  )
  WHERE id = NEW.livreur_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Déclencheur pour mettre à jour note_moyenne à chaque insertion
DROP TRIGGER IF EXISTS trigger_update_note_moyenne ON public.evaluations_livreurs;
CREATE TRIGGER trigger_update_note_moyenne
  AFTER INSERT OR UPDATE ON public.evaluations_livreurs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_livreur_note_moyenne();
