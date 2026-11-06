# Bureau ARN et Vie de l’ARN

## Bureau administrateur

Après connexion et double vérification, le menu latéral donne accès au tableau de bord, aux candidatures, aux formateurs, aux avis clients et à la Vie de l’ARN. Les compteurs proviennent de la base : candidatures en attente, profils publiés, formateurs, brouillons et publications en ligne. Un compteur indisponible est indiqué par un tiret, jamais par un faux zéro.

## Créer une publication

1. Dans **Vie de l’ARN**, choisir L’association, Réalisation, Projet ou Actualité.
2. Renseigner un titre, le texte et éventuellement un résumé, une date et jusqu’à quatre photos. Pour un projet, préciser son état : envisagé, en préparation, en cours ou terminé.
3. Laisser **Publier sur le site de l’ARN** décoché pour garder un brouillon privé. Cocher cette case pour publier.
4. La liste permet de modifier, publier, retirer du site en conservant un brouillon ou supprimer définitivement un contenu.

Les photos ajoutées lors d’une modification remplacent la sélection actuelle. Sans nouveau fichier et sans demander leur retrait, les photos existantes sont conservées. Le public peut filtrer les rubriques et ouvrir un article complet et sa galerie.

## Sécurité

- Les publications de travail ne sont lisibles et modifiables que par les administrateurs ARN ayant validé la MFA (AAL2), via les politiques PostgreSQL existantes.
- `arn_publications` contient les brouillons privés. Un déclencheur publie uniquement les contenus marqués en ligne dans `arn_vie_publique`, en lecture seule pour les visiteurs.
- Les photos de travail sont privées dans `arn-vie-privee`. L’éditeur utilise des liens signés de cinq minutes. Lors de la publication, des copies sont créées dans `arn-vie-publique` ; les URL publiques sont destinées à être accessibles aux visiteurs.
- Un retrait supprime d’abord la projection publique puis nettoie les copies publiques. Le brouillon et ses originaux restent privés. Une suppression supprime la ligne et sa projection, puis nettoie les deux espaces de photos via l’API Storage.
- En cas de problème de nettoyage, l’interface le signale. Un résultat d’écriture incertain conserve les fichiers pour éviter de casser une publication qui aurait été enregistrée.
- Les modifications utilisent la date de dernière modification comme contrôle de concurrence. Une fiche modifiée par un autre administrateur doit être actualisée avant de réessayer.
- Les textes sont affichés comme du texte, avec échappement HTML. Aucun contenu public ni fait associatif fictif n’a été créé pour remplir la vitrine.

La migration `arn_bureau_publications_vie_association` est déjà appliquée au projet ARN. `vie-arn.sql` en conserve la source ; ne pas la réexécuter sur la même base.

## Vérifications

Tests transactionnels annulés après exécution : refus des écritures à AAL1, contrôle administrateur MFA, confidentialité des brouillons, validation des chemins de photos, lecture seule publique, publication, modification, retrait et suppression en cascade. Tests DOM : navigation du bureau, édition et réinitialisation du type de projet, filtres publics, contenu complet des articles, échappement HTML, labels et identifiants uniques. Les contrôles préexistants de l’annuaire et des avis ont également été vérifiés.
