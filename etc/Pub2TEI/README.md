Pub2TEI
=======

##### Version:
Cette version est conforme au dépôt git *Privé* originel mais sans les Samples pour passer en *Public*
Version du dépôt https://github.com/kermitt2/Pub2TEI (branche ajouts_romain, commit 5c4d084)
2015-08-10 - Romain Loth


### Quelques infos sur Pub2TEI: 
Pub2TEI est un ensemble de transfos XSLT v2.0 pour passer de formats XML
spécifiques aux éditeurs (publishers) à un format TEI commun.

Il a été développé dans le cadre du projet PEER, notamment par L. Romary
et P. Lopez.

Ces feuilles sont reprises dans le cadre du projet ISTEX notamment pour
convertir les références bibliographiques natives en corpus gold ou en
corpus d'entraînement.


### La feuille principale est Publishers.xsl:
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

