# Formateurs, métiers et avis

## Utilisation

- Site public : onglets **Métiers et services**, **Formateurs**, **Donner un avis**.
- Administration : onglets **Candidatures**, **Formateurs**, **Avis clients**, après connexion et double vérification.
- Formateurs : prénom, nom, téléphone, courriel, domaine, présentation, photo et évaluation ARN facultative de 1 à 5 étoiles. Le bouton **Modifier / noter** permet de changer la fiche ou la note. L'accord du formateur est demandé avant publication.
- Métiers : toutes les catégories sont accessibles, avec le nombre de profils approuvés. Les libellés Plombier/Plomberie et Électricien/Électricité sont regroupés. Les métiers personnalisés apparaissent également.
- Avis clients : après une prestation, l'administrateur choisit le professionnel ou le formateur et crée un lien personnel à transmettre au bénéficiaire. Le lien expire après 30 jours et accepte une seule évaluation. Les liens en attente peuvent être révoqués. Le client vérifie son lien, voit le nom de la personne concernée puis attribue 1 à 5 étoiles.
- La note ARN et la moyenne des clients sont séparées. Une fiche sans avis ne reçoit aucune note fictive. Le nombre d'avis accompagne la moyenne.

## Sécurité et limites

- Gestion des formateurs et liens réservée aux administrateurs ARN avec MFA AAL2, vérifiée aussi par les politiques PostgreSQL.
- Aucun accès public à la liste des liens ou aux votes individuels. Seuls les agrégats des profils publiés sont accessibles.
- Codes UUID aléatoires : consommation sous verrou, vote unique et calcul atomique des agrégats. Les erreurs annulent toute la transaction.
- Les invitations sont liées au professionnel ou au formateur ; la personne évaluée ne peut pas être modifiée par le votant.
- Une invitation ne prouve pas indépendamment qu'une prestation a eu lieu. ARN doit contrôler la délivrance et transmettre chaque lien au seul bénéficiaire. Le détenteur du lien peut voter sans compte.
- Les photos des formateurs sont publiques après leur publication. Téléversements et suppressions sont réservés aux administrateurs avec MFA ; les images sont converties en WebP.
- La suppression d'une fiche supprime aussi les liens et notes associés. Le nettoyage Storage passe par son API ; si une photo ne peut être supprimée, l'interface le signale pour intervention.
- Les seuils existants des candidatures et la double vérification restent actifs. La protection contre les mots de passe compromis dépend toujours de l'offre Supabase.

## Base et publication

Les migrations `arn_formateurs_avis_services` et `arn_avis_lien_identification` sont déjà appliquées au projet Supabase ARN. `formateurs-avis.sql` en conserve la source : ne pas l'exécuter à nouveau sur ce projet.

Fichiers de cette extension : `index.html`, `admin.html`, `community.css`, `sw.js`. Les empreintes CSP des scripts intégrés ont été recalculées ; le cache du site passe à `arn-shell-v8`. L'administration n'est pas mise en cache hors ligne.

Vérifications : tests de permissions anon/AAL1/AAL2, création et mise à jour d'un formateur, avis professionnel et formateur, moyenne de deux votes, lien consommé/expiré/révoqué, cascade de suppression, filtres par métier et alias, échappement HTML, onglets administrateur, labels et identifiants uniques. Les données de test SQL ont été annulées par ROLLBACK.
