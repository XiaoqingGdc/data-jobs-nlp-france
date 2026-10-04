-- Schéma de la base offres_data
-- Exécuté automatiquement par le conteneur postgres au premier démarrage.

-- 1. Offres : une ligne par offre, mise à jour à chaque collecte
CREATE TABLE IF NOT EXISTS offres (
    id                 TEXT PRIMARY KEY,          -- identifiant France Travail
    intitule           TEXT,
    description        TEXT,
    metier             TEXT,                      -- Data Analyst / Data Engineer / Data Scientist (règles sur l'intitulé)
    date_creation      TIMESTAMPTZ,
    date_actualisation TIMESTAMPTZ,
    departement        TEXT,
    lieu_libelle       TEXT,
    type_contrat       TEXT,
    experience_exige   TEXT,
    salaire_libelle    TEXT,                      -- texte brut, ex. "Annuel de 35000 Euros à 45000 Euros"
    salaire_min_annuel NUMERIC,                   -- rempli après parsing regex
    salaire_max_annuel NUMERIC,
    entreprise_nom     TEXT,
    raw                JSONB,                     -- JSON complet : permet de re-parser plus tard sans re-collecter
    first_seen         DATE NOT NULL DEFAULT CURRENT_DATE,   -- 1er jour où l'offre a été vue
    last_seen          DATE NOT NULL DEFAULT CURRENT_DATE    -- dernier jour où elle était encore en ligne
);

CREATE INDEX IF NOT EXISTS idx_offres_metier      ON offres (metier);
CREATE INDEX IF NOT EXISTS idx_offres_departement ON offres (departement);
CREATE INDEX IF NOT EXISTS idx_offres_creation    ON offres (date_creation);

-- 2. Journal des collectes : prouve que l'automatisation tourne, et sert au suivi des erreurs
CREATE TABLE IF NOT EXISTS collectes (
    id           SERIAL PRIMARY KEY,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at  TIMESTAMPTZ,
    nb_offres    INTEGER,
    nb_nouvelles INTEGER,
    statut       TEXT                              -- 'ok' / 'erreur'
);

-- 3. Requête d'insertion utilisée dans n8n (nœud Postgres, mode "Execute Query") :
--    nouvelle offre -> insérée ; offre déjà connue -> on met seulement à jour last_seen
--
-- INSERT INTO offres (id, intitule, description, metier, date_creation, date_actualisation,
--                     departement, lieu_libelle, type_contrat, experience_exige,
--                     salaire_libelle, entreprise_nom, raw)
-- VALUES (...)
-- ON CONFLICT (id) DO UPDATE
--     SET last_seen          = CURRENT_DATE,
--         date_actualisation = EXCLUDED.date_actualisation;

-- 4. Vue d'analyse : durée en ligne de chaque offre
CREATE OR REPLACE VIEW v_duree_en_ligne AS
SELECT
    id,
    metier,
    departement,
    first_seen,
    last_seen,
    (last_seen - first_seen) AS jours_en_ligne,
    (last_seen < CURRENT_DATE - 1) AS retiree       -- plus vue depuis plus d'un jour
FROM offres;

-- 5. Vue d'analyse : nouvelles offres par semaine et par métier (pour Power BI)
CREATE OR REPLACE VIEW v_offres_par_semaine AS
SELECT
    DATE_TRUNC('week', first_seen)::date AS semaine,
    metier,
    COUNT(*) AS nb_offres
FROM offres
GROUP BY 1, 2
ORDER BY 1, 2;
