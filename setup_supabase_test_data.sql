-- 1. Activer l'extension PostGIS pour la géolocalisation
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Création de la table des profils (si pas déjà faite)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT auth.uid(),
    email TEXT,
    role TEXT CHECK (role IN ('livreur', 'boutiquier', 'fournisseur')),
    nom TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Création de la table des commandes
CREATE TABLE IF NOT EXISTS public.commandes (
    id SERIAL PRIMARY KEY,
    client_id UUID REFERENCES auth.users(id),
    statut TEXT DEFAULT 'en_cours',
    montant_total DECIMAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Création de la table de tracking (Celle utilisée par la carte)
CREATE TABLE IF NOT EXISTS public.tracking_livreurs (
    id SERIAL PRIMARY KEY,
    livreur_id UUID, -- Peut être lié à profiles.id plus tard
    commande_id INTEGER REFERENCES public.commandes(id),
    position GEOMETRY(POINT, 4326),
    derniere_mise_a_jour TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. INSERTION DES DONNÉES DE TEST
-- On insère une commande fictive (ID 1)
-- Note : On ne peut pas mettre de client_id réel facilement ici sans UUID, 
-- donc on laisse client_id à NULL pour le test.
INSERT INTO public.commandes (id, statut, montant_total)
VALUES (1, 'en_livraison', 5000)
ON CONFLICT (id) DO NOTHING;

-- On insère la ligne de tracking que le code va surveiller (commande_id = 1)
INSERT INTO public.tracking_livreurs (id, commande_id, position)
VALUES (1, 1, ST_GeomFromText('POINT(-17.4624 14.6912)', 4326))
ON CONFLICT (id) DO NOTHING;

-- 6. ACTIVER LE TEMPS RÉEL (REALTIME)
-- Cette étape est CRUCIALE pour que la carte bouge toute seule
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE public.tracking_livreurs;
COMMIT;
