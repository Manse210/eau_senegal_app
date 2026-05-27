| table_name        | column_name          | data_type                   | is_nullable | column_default                                |
| ----------------- | -------------------- | --------------------------- | ----------- | --------------------------------------------- |
| boutiquier        | id                   | uuid                        | NO          | null                                          |
| boutiquier        | email                | text                        | YES         | null                                          |
| boutiquier        | role                 | text                        | YES         | 'boutiquier'::text                            |
| boutiquier        | created_at           | timestamp without time zone | YES         | now()                                         |
| commande_items    | id                   | uuid                        | NO          | gen_random_uuid()                             |
| commande_items    | commande_id          | uuid                        | YES         | null                                          |
| commande_items    | produit_id           | uuid                        | YES         | null                                          |
| commande_items    | quantity             | integer                     | NO          | null                                          |
| commande_items    | price_at_order       | numeric                     | YES         | null                                          |
| commande_items    | created_at           | timestamp without time zone | YES         | now()                                         |
| commandes         | id                   | uuid                        | NO          | gen_random_uuid()                             |
| commandes         | boutiquier_id        | uuid                        | YES         | null                                          |
| commandes         | status               | text                        | YES         | 'en_attente'::text                            |
| commandes         | total_price          | numeric                     | YES         | null                                          |
| commandes         | created_at           | timestamp without time zone | YES         | now()                                         |
| commandes         | updated_at           | timestamp without time zone | YES         | now()                                         |
| fournisseur       | id                   | uuid                        | NO          | null                                          |
| fournisseur       | email                | text                        | YES         | null                                          |
| fournisseur       | role                 | text                        | YES         | 'fournisseur'::text                           |
| fournisseur       | created_at           | timestamp without time zone | YES         | now()                                         |
| geography_columns | f_table_catalog      | name                        | YES         | null                                          |
| geography_columns | f_table_schema       | name                        | YES         | null                                          |
| geography_columns | f_table_name         | name                        | YES         | null                                          |
| geography_columns | f_geography_column   | name                        | YES         | null                                          |
| geography_columns | coord_dimension      | integer                     | YES         | null                                          |
| geography_columns | srid                 | integer                     | YES         | null                                          |
| geography_columns | type                 | text                        | YES         | null                                          |
| geometry_columns  | f_table_catalog      | character varying           | YES         | null                                          |
| geometry_columns  | f_table_schema       | name                        | YES         | null                                          |
| geometry_columns  | f_table_name         | name                        | YES         | null                                          |
| geometry_columns  | f_geometry_column    | name                        | YES         | null                                          |
| geometry_columns  | coord_dimension      | integer                     | YES         | null                                          |
| geometry_columns  | srid                 | integer                     | YES         | null                                          |
| geometry_columns  | type                 | character varying           | YES         | null                                          |
| livreur           | id                   | uuid                        | NO          | null                                          |
| livreur           | email                | text                        | YES         | null                                          |
| livreur           | role                 | text                        | YES         | 'livreur'::text                               |
| livreur           | created_at           | timestamp without time zone | YES         | now()                                         |
| produits          | id                   | uuid                        | NO          | gen_random_uuid()                             |
| produits          | nom                  | text                        | NO          | null                                          |
| produits          | marque               | text                        | NO          | null                                          |
| produits          | prix                 | numeric                     | NO          | null                                          |
| produits          | fournisseur_id       | uuid                        | YES         | null                                          |
| produits          | stock                | integer                     | YES         | 100                                           |
| produits          | description          | text                        | YES         | null                                          |
| produits          | image_url            | text                        | YES         | null                                          |
| produits          | couleur_theme        | text                        | YES         | null                                          |
| produits          | created_at           | timestamp without time zone | YES         | now()                                         |
| produits          | updated_at           | timestamp without time zone | YES         | now()                                         |
| profiles          | id                   | uuid                        | NO          | null                                          |
| profiles          | nom                  | text                        | NO          | null                                          |
| profiles          | telephone            | text                        | NO          | null                                          |
| profiles          | role                 | text                        | NO          | null                                          |
| profiles          | nom_commerce         | text                        | YES         | null                                          |
| profiles          | created_at           | timestamp with time zone    | YES         | now()                                         |
| spatial_ref_sys   | srid                 | integer                     | NO          | null                                          |
| spatial_ref_sys   | auth_name            | character varying           | YES         | null                                          |
| spatial_ref_sys   | auth_srid            | integer                     | YES         | null                                          |
| spatial_ref_sys   | srtext               | character varying           | YES         | null                                          |
| spatial_ref_sys   | proj4text            | character varying           | YES         | null                                          |
| tracking_livreurs | id                   | integer                     | NO          | nextval('tracking_livreurs_id_seq'::regclass) |
| tracking_livreurs | livreur_id           | uuid                        | YES         | null                                          |
| tracking_livreurs | commande_id          | integer                     | YES         | null                                          |
| tracking_livreurs | position             | USER-DEFINED                | YES         | null                                          |
| tracking_livreurs | derniere_mise_a_jour | timestamp with time zone    | YES         | now() 





## Table `boutiquier`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `email` | `text` |  Nullable |
| `role` | `text` |  Nullable |
| `created_at` | `timestamp` |  Nullable |

## Table `commande_items`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `commande_id` | `uuid` |  Nullable |
| `produit_id` | `uuid` |  Nullable |
| `quantity` | `int4` |  |
| `price_at_order` | `numeric` |  Nullable |
| `created_at` | `timestamp` |  Nullable |

## Table `commandes`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `boutiquier_id` | `uuid` |  Nullable |
| `status` | `text` |  Nullable |
| `total_price` | `numeric` |  Nullable |
| `created_at` | `timestamp` |  Nullable |
| `updated_at` | `timestamp` |  Nullable |
| `livreur_id` | `uuid` |  Nullable |
| `nom` | `text` |  Nullable |
| `payment_method` | `text` |  Nullable |
| `payment_transaction_id` | `text` |  Nullable |

## Table `fournisseur`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `email` | `text` |  Nullable |
| `role` | `text` |  Nullable |
| `created_at` | `timestamp` |  Nullable |

## Table `livreur`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `email` | `text` |  Nullable |
| `role` | `text` |  Nullable |
| `created_at` | `timestamp` |  Nullable |

## Table `produits`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `nom` | `text` |  |
| `marque` | `text` |  |
| `prix` | `numeric` |  |
| `fournisseur_id` | `uuid` |  Nullable |
| `stock` | `int4` |  Nullable |
| `description` | `text` |  Nullable |
| `image_url` | `text` |  Nullable |
| `couleur_theme` | `text` |  Nullable |
| `created_at` | `timestamp` |  Nullable |
| `updated_at` | `timestamp` |  Nullable |

## Table `profiles`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `nom` | `text` |  |
| `telephone` | `text` |  |
| `role` | `text` |  |
| `nom_commerce` | `text` |  Nullable |
| `created_at` | `timestamptz` |  Nullable |

## Table `spatial_ref_sys`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `srid` | `int4` | Primary |
| `auth_name` | `varchar` |  Nullable |
| `auth_srid` | `int4` |  Nullable |
| `srtext` | `varchar` |  Nullable |
| `proj4text` | `varchar` |  Nullable |

## Table `tracking_livreurs`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `int4` | Primary |
| `livreur_id` | `uuid` |  Nullable Unique |
| `commande_id` | `int4` |  Nullable |
| `position` | `geometry` |  Nullable |
| `derniere_mise_a_jour` | `timestamptz` |  Nullable |

|