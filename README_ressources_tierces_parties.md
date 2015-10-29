Ressources upstream
====================

Ce module importe les transformations Pub2TEI (du projet PEER) dans le dossier etc/ comme point de départ pour les conversions body dans certaines branches du projet Istex, et en branche principale dans la refbib-stack pour convertir les références bibliographiques natives en corpus gold ou en corpus d'entraînement.


#### Version:
Cette version est conforme au [dépôt git *Public*](https://github.com/kermitt2/Pub2TEI) de Laurent Romary et Patrice Lopez qui comporte des documents-exemples obfusqués pour respecter les droits d'auteurs. Une transformation pour les exemples IOP y a déjà été inclue par le projet ISTEX, d'autres branches de modifications (feuille Nature, bibliographies Elsevier) y seront re-mergées prochainement.

#### Flux des dépendances upstream => downstream

```
dépôt privé chez Patrice Lopez
 + merges des branches ISTEX
   ------------------------
              \
    dépôt public https://github.com/kermitt2/Pub2TEI
       (sans les exemples sous droits d'auteurs)
           ----------------------- 
                  \
            dépôt istex-rd libconsulte
        (subtree dans le dossier ./etc/Pub2TEI)
           ----------------------- 
                  \  \  \
        différents dépôts qui utilisent libconsulte
```



### Quelques infos sur Pub2TEI:

#### Vue générale
Pub2TEI est un ensemble de transformations XSLT v2.0 pour passer de formats XML spécifiques aux éditeurs (publishers) à un format TEI commun.

Il a été développé dans le cadre du projet PEER, notamment par L. Romary et P. Lopez.



#### Structure
La feuille principale est Publishers.xsl:

 - elle trie les cas de figure selon la balise racine observée dans l'input
 - elle importe toutes les autres feuilles de 2 façons :
    - via Imports.xsl pour chaque composant spécifique qu'on peut trouver (biblio, tables,...)
    - directement pour chaque "publisher", pour savoir ramener les données de chaque 
      éditeur sur un même squelette TEI c'est-à-dire une séquence de la forme:
```
<TEI>
    <teiHeader>
        <fileDesc>...</fileDesc>
        <profileDesc>...<profileDesc>
    </teiHeader>
    <text>
        <front>...</front>
        <body>...</body>
        <back></back>
    </text>
</TEI>
```

La logique est donc "input-guided" pour générer le squelette et 
"output-guided" pour remplir les sous-branches spécifiques.

