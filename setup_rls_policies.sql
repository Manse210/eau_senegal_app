-- ==============================================================
--  CONFIGURATION RLS (Row Level Security) - Eau Sénégal
--  À exécuter DANS LE SQL EDITOR du dashboard Supabase
-- ==============================================================

-- 1. ACTIVER RLS SUR TOUTES LES TABLES
ALTER TABLE public.boutiquier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fournisseur ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.livreur ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commande_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracking_livreurs ENABLE ROW LEVEL SECURITY;

-- 2. SUPPRIMER LES ANCIENNES POLICIES (pour permettre les mises à jour)
DROP POLICY IF EXISTS "Lecture publique produits" ON public.produits;
DROP POLICY IF EXISTS "Insertion par fournisseur" ON public.produits;
DROP POLICY IF EXISTS "Modification par fournisseur" ON public.produits;
DROP POLICY IF EXISTS "Suppression par fournisseur" ON public.produits;

-- ==============================================================
--  TABLE: profiles
-- ==============================================================
-- Un utilisateur peut lire son propre profil
CREATE POLICY "Lecture propre profil" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Insertion lors de l'inscription (id = auth.uid())
CREATE POLICY "Insertion lors inscription" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Modification de son propre profil
CREATE POLICY "Modification propre profil" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ==============================================================
--  TABLE: boutiquier
-- ==============================================================
CREATE POLICY "Lecture propre profil boutiquier" ON public.boutiquier
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Insertion boutiquier" ON public.boutiquier
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ==============================================================
--  TABLE: fournisseur
-- ==============================================================
CREATE POLICY "Lecture propre profil fournisseur" ON public.fournisseur
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Insertion fournisseur" ON public.fournisseur
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ==============================================================
--  TABLE: livreur
-- ==============================================================
CREATE POLICY "Lecture propre profil livreur" ON public.livreur
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Insertion livreur" ON public.livreur
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Les fournisseurs peuvent lister tous les livreurs (pour assignation)
CREATE POLICY "Fournisseurs listent livreurs" ON public.livreur
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- ==============================================================
--  TABLE: produits
-- ==============================================================
-- Tout le monde connecté peut voir les produits
CREATE POLICY "Lecture publique produits" ON public.produits
  FOR SELECT USING (auth.role() = 'authenticated');

-- Les fournisseurs peuvent ajouter des produits
CREATE POLICY "Insertion par fournisseur" ON public.produits
  FOR INSERT WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- Un fournisseur peut modifier ses propres produits
CREATE POLICY "Modification par fournisseur" ON public.produits
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

CREATE POLICY "Suppression par fournisseur" ON public.produits
  FOR DELETE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- ==============================================================
--  TABLE: commandes
-- ==============================================================
-- Un boutiquier voit uniquement ses propres commandes
CREATE POLICY "Boutiquier voit ses commandes" ON public.commandes
  FOR SELECT USING (auth.uid() = boutiquier_id);

-- Un boutiquier peut créer une commande (boutiquier_id = son UID)
CREATE POLICY "Boutiquier crée commande" ON public.commandes
  FOR INSERT WITH CHECK (
    auth.uid() = boutiquier_id
    AND auth.jwt() -> 'user_metadata' ->> 'role' = 'boutiquier'
  );

-- Un fournisseur voit TOUTES les commandes
CREATE POLICY "Fournisseur voit toutes commandes" ON public.commandes
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- Un fournisseur peut modifier le statut de n'importe quelle commande
CREATE POLICY "Fournisseur modifie commandes" ON public.commandes
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- Un livreur voit les commandes qui lui sont assignées
CREATE POLICY "Livreur voit commandes assignées" ON public.commandes
  FOR SELECT USING (auth.uid() = livreur_id);

-- Un livreur peut marquer comme livrée une commande qui lui est assignée (validation OTP)
CREATE POLICY "Livreur valide livraison" ON public.commandes
  FOR UPDATE USING (auth.uid() = livreur_id)
  WITH CHECK (auth.uid() = livreur_id);

-- ==============================================================
--  TABLE: commande_items
-- ==============================================================
-- Un boutiquier voit les items de ses commandes
CREATE POLICY "Boutiquier voit items" ON public.commande_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.commandes
      WHERE commandes.id = commande_items.commande_id
      AND commandes.boutiquier_id = auth.uid()
    )
  );

-- Un fournisseur voit tous les items
CREATE POLICY "Fournisseur voit tous items" ON public.commande_items
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- Un livreur voit les items des commandes qui lui sont assignées
CREATE POLICY "Livreur voit items assignés" ON public.commande_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.commandes
      WHERE commandes.id = commande_items.commande_id
      AND commandes.livreur_id = auth.uid()
    )
  );

-- Insertion lors de la création d'une commande
CREATE POLICY "Insertion items commande" ON public.commande_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.commandes
      WHERE commandes.id = commande_items.commande_id
      AND commandes.boutiquier_id = auth.uid()
    )
  );

-- ==============================================================
--  TABLE: tracking_livreurs
-- ==============================================================
-- Un livreur peut insérer/mettre à jour son propre tracking
CREATE POLICY "Livreur gère son tracking" ON public.tracking_livreurs
  FOR ALL USING (auth.uid() = livreur_id)
  WITH CHECK (auth.uid() = livreur_id);

-- Un boutiquier peut voir le tracking du livreur assigné à sa commande
CREATE POLICY "Boutiquier voit tracking livreur" ON public.tracking_livreurs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.commandes
      WHERE commandes.livreur_id = tracking_livreurs.livreur_id
      AND commandes.boutiquier_id = auth.uid()
      AND commandes.status = 'en_livraison'
    )
  );

-- Un fournisseur peut voir tout le tracking
CREATE POLICY "Fournisseur voit tout tracking" ON public.tracking_livreurs
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- Un fournisseur peut initialiser une ligne de tracking (pour préparer la livraison)
CREATE POLICY "Fournisseur init tracking" ON public.tracking_livreurs
  FOR INSERT WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

CREATE POLICY "Fournisseur update tracking" ON public.tracking_livreurs
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

-- ==============================================================
--  ACTIVER REALTIME SUR commandes (en plus de tracking_livreurs)
-- ==============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime FOR TABLE public.tracking_livreurs;
  ELSE
    -- Ajouter commandes si pas déjà présente
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'commandes'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.commandes;
    END IF;
  END IF;
END
$$;
