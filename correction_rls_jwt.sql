-- ==============================================================
--  CORRECTION : auth.jwt() ->> 'role' → auth.jwt() -> 'user_metadata' ->> 'role'
--  Le role est stocké dans user_metadata du JWT, pas à la racine
-- ==============================================================

DROP POLICY IF EXISTS "Fournisseurs listent livreurs" ON public.livreur;
CREATE POLICY "Fournisseurs listent livreurs" ON public.livreur
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Insertion par fournisseur" ON public.produits;
CREATE POLICY "Insertion par fournisseur" ON public.produits
  FOR INSERT WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Modification par fournisseur" ON public.produits;
CREATE POLICY "Modification par fournisseur" ON public.produits
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Suppression par fournisseur" ON public.produits;
CREATE POLICY "Suppression par fournisseur" ON public.produits
  FOR DELETE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Boutiquier crée commande" ON public.commandes;
CREATE POLICY "Boutiquier crée commande" ON public.commandes
  FOR INSERT WITH CHECK (
    auth.uid() = boutiquier_id
    AND auth.jwt() -> 'user_metadata' ->> 'role' = 'boutiquier'
  );

DROP POLICY IF EXISTS "Fournisseur voit toutes commandes" ON public.commandes;
CREATE POLICY "Fournisseur voit toutes commandes" ON public.commandes
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Fournisseur modifie commandes" ON public.commandes;
CREATE POLICY "Fournisseur modifie commandes" ON public.commandes
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Fournisseur voit tous items" ON public.commande_items;
CREATE POLICY "Fournisseur voit tous items" ON public.commande_items
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Fournisseur voit tout tracking" ON public.tracking_livreurs;
CREATE POLICY "Fournisseur voit tout tracking" ON public.tracking_livreurs
  FOR SELECT USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Fournisseur init tracking" ON public.tracking_livreurs;
CREATE POLICY "Fournisseur init tracking" ON public.tracking_livreurs
  FOR INSERT WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');

DROP POLICY IF EXISTS "Fournisseur update tracking" ON public.tracking_livreurs;
CREATE POLICY "Fournisseur update tracking" ON public.tracking_livreurs
  FOR UPDATE USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'fournisseur');
