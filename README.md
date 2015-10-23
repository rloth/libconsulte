Echantillons de docs depuis l'API ISTEX
=========================================
**3 routines pour requêter/échantilloner/récupérer des documents**

### Points d'entrée

**`sampler.py`** pour piocher une liste d'ID au hasard, (/!\\ avec représentativité!)

**`corpusdirs.py`** pour récupérer les fulltexts et métadonnées pour une liste d'IDs


### Usage courant

L'essentiel tient en 2 commandes:

```
# échantilloner 100 docs par date
python3 sampler.py -n 100 -c publicationDate -o tab > mes_100_documents.tsv

# récupérer dans mon_nouveau_corpus
python3 corpusdirs.py mon_nouveau_corpus --from_table mes_100_documents.tsv
```

#### Explications
Ici on veut 100 documents avec un peu de chaque période dans la base Istex (par exemple pour tester leur qualité OCR).

##### 1) Echantillonner

```
python3 sampler.py -n 100 -c publicationDate -o tab > mes_100_documents.tsv
```

  - il va piocher 100 IDS au hasard par quota sur publicationDate.
  - le tirage par quota assure le "un peu de chaque"
    - par ex: dans la base j'ai 2 millions de docs de la période *[1960 à 1979]* sur 20.000.000 au total
    - la méthode par quota va en tirer 10 de cette période pour les 100 qu'on lui a demandés (règle de 3).
  - le script propose différents formats de sortie: ici on lui a demandé la sortie tabulée avec `-o tab`

##### 2) Récupérer

Ensuite on veut obtenir les documents : avec `corpusdirs.py`, on peut lancer les téléchargements dans un nouveau dossier de notre choix.


```
python3 corpusdirs.py mon_nouveau_corpus --from_table mes_100_documents.tsv
```

  - on voit qu'on réutilise la table `mes_100_documents.tsv` obtenue de l'échantilloneur comme liste de documents à télécharger/traiter.
  - corpusdirs va:
    - télécharger les PDF
    - télécharger les XML natifs
      - lier la DTD des XML natifs en local
    - convertir les XML natifs en TEI



## Détails techniques

### Sorties

#### Sortie de corpusdirs

Tout cela sera stocké sous `mon_nouveau_corpus/data` avec la structure suivante:

```
tree mon_nouveau_corpus

mon_nouveau_corpus
   ├── data
   │   ├── A-pdfs
   │   │   ├── els-63DD13DF0D6186E15D0C15A3CF0E68FC01BC22F8.pdf
   │   │   ├── wil-2027F65F05E2F0DDEA37C64869B5729F5CDA8B3C.pdf
   │   │   ├── oup-652D02E55E57E3091F4D2B2B28219844A770F83D.pdf
   │   │   └── (...)
   │   ├── B-xmlnatifs
   │   │   ├── els-63DD13DF0D6186E15D0C15A3CF0E68FC01BC22F8.xml
   │   │   ├── wil-2027F65F05E2F0DDEA37C64869B5729F5CDA8B3C.xml
   │   │   ├── oup-652D02E55E57E3091F4D2B2B28219844A770F83D.xml
   │   │   └── (...)
   │   └── C-goldxmltei
   │       ├── els-63DD13DF0D6186E15D0C15A3CF0E68FC01BC22F8.tei.xml
   │       ├── wil-2027F65F05E2F0DDEA37C64869B5729F5CDA8B3C.tei.xml
   │       ├── oup-652D02E55E57E3091F4D2B2B28219844A770F83D.tei.xml
   │       └── (...)
   └── meta
      ├── infos.tab          # tableau TSV résumé (date, titre, auteur 1, ID,  corpus...)
      ├── basenames.ls         # liste des noms de fichiers
      └── shelf_triggers.json    # liste des sous-dossiers remplis
```

Chaque sous-dossier s'appelle "shelf" ou "étagère". Il est faisable d'en ajouter d'autres dans la configuration de corpusdirs.


#### Sortie tabulée de l'échantillonneur

L'échantilloneur a 3 types de sorties possibles, selon l'option -o

  - "ids":  simplement une liste d'identifiants de l'api
     - ex: `sampler.py -o ids -n 20 > my_ids.txt`
  - "docs": télécharger les docs pdf uniquement dans un dossier `echantillon_$date-$heure`
     - ex: `sampler.py -o docs -n 20`
  - "tab": sortie tabulée 
     - ex: `sampler.py -o tab -n 20 > my_tab.tsv`
     - peut être utilisée dans excel
     - peut être utilisée corpusdirs pour un téléchargements des docs plus avancé

<table>
<tr><td>istex_id</td>   <td>corpus</td>  <td>pub_period</td>     <td>pdfver</td> <td>...</td>  <td>title</td></tr>
<tr><td>63DD13D...</td> <td>els</td>   <td>[1980 TO 1989]</td>   <td>1.2</td>   <td>...</td>  <td>Measurements of the total transmittance of the solar radiation...</td></tr>
<tr><td>2027F65...</td> <td>wil</td>    <td>[2000 TO *]</td>     <td>1.4</td>   <td>...</td>  <td>Appropriate dosing of antiarrhythmic drugs in Japan...</td></tr>
<tr><td>652D02E...</td> <td>oup</td>    <td>[* TO 1959]</td>     <td>1.2</td>  <td>...</td>  <td>"Once upon a time."</td></tr>
<tr><td>etc</td> <td>etc</td>    <td>etc</td>     <td>etc</td>  <td>etc</td>  <td>etc</td></tr>
</table>


### Valeurs pour chaque facette

Pour calculer la représentativité, l'échantilloneur doit connaître les facettes possibles d'un champ. Si on lui donne comme critère de représentativité `corpusName`, il va s'informer en interrogeant [la route facette correspondante de l'API](https://api.istex.fr/documentation/300-search.html#facettes). Pour d'autres champs, il utilise des listes des valeurs possibles (toutes comme pour categories.wos ou une partition en paquets pour les facettes de type range, les langues et les genres). Ces listes sont inscrites dans le module field_value_lists.py

Les champs utilisables comme critère d'échantillonnage sont:

  - `corpusName`
  - `qualityIndicators.pdfVersion`
  - `qualityIndicators.refBibsNative`
  - `language`
  - `genre`
  - `categories.wos`
  - `publicationDate`
  - `copyrightDate`
  - `qualityIndicators.pdfCharCount`

### Interaction avec l'API

**`api.py`** gère toute l'interaction lowlevel avec l'[API](https://api.istex.fr).  
Les fonctions principales sont les suivantes :


```
search(q, limit=None, n_docs=None, outfields=('title', 'host.issn', 'fulltext'), i_from=0)
terms_facet(facet_name, q='*')
count(q, api_conf={'host': 'api.istex.fr', 'route': 'document'})
write_fulltexts(doc_id, tgt_dir='.', login, passw, api_types=['fulltext/pdf', 'metadata/xml']`
```

Les modules sampler.py et corpusdirs.py l'importent et utilisent ces fonctions.

### TODO

  - pour les formats tabulés, mettre la liste des colonnes dans un config externe
      - Toutes les colonnes actuelles: istex_id,corpus,pub_year,pub_period,pdfver,pdfwc,bibnat,author_1,lang,doctype_1,cat_sci,title
  - rétablir contrainte -w sur sampler
  - ajouter une étagère par défaut pour les MODS2TEI dans corpusdirs



```
# pour plus d'infos:
python3 sampler.py -h
python3 corpusdirs.py -h
```
