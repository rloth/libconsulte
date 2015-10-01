<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0" xmlns="http://www.tei-c.org/ns/1.0">
       
    <!--created by romain dot loth at inist.fr
                ISTEX-CNRS 2015-01-->
    <xsl:output encoding="UTF-8" method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>

    <!--
        CETTE TEMPLATE NE DEVRAIT PAS ETRE LANCEE DIRECTEMENT, 
        => PASSER PAR >> PUBLISHERS.XSL <<
        
        NB: entre autres défini en amont dans Publishers : param name="biblType" 
        bibl ou biblStruct selon la sortie voulue ("+ fidèle" vs "+ structurée") 
        
        
        =============================
        TODO dans les entrées Nature
        =============================
          RL:
           - rajouter le namespace TEI en haut
           - le header est minimaliste
           - le body n'est pas fait
           - en mode 'bibl', on ajoute des attributs @rend qui servent en
             préparation de l'entrainement de grobid
           
           £=> et une fois fini mettre un exemple de sortie dans Samples/TestOutputTEI
    -->

    <!--
        ****************
        SQUELETTE GLOBAL
        ****************
        IN: /. <<

        OUT:
        /TEI/teiHeader/fileDesc/titleStmt >>
        /TEI/teiHeader/fileDesc/sourceDesc/biblStruct >>
    /TEI/teiHeader/profileDesc/
    -->
    <xsl:template match="/article[starts-with(pubfm/cpg/cpn, 'Nature')]
                       | /article[starts-with(pubfm/cpg/cpn, 'Macmillan')]
                       | /headerx[starts-with(pubfm/cpg/cpn, 'Nature')]
                       | /headerx[starts-with(pubfm/cpg/cpn, 'Macmillan')]">
        <TEI>
            <teiHeader>
                <fileDesc>
                    <titleStmt>
                        <!-- reprise du titre principal avec son topic éventuel 
                             (copie sans dans sourceDesc) -->
                        <title>
                            <xsl:apply-templates select="fm/atl" mode="intitle"/>
                        </title>
                        <!-- proposition d'un "stamp" Pub2TEI -->
                        <respStmt>
                            <resp>Partial conversion from Nature (NPG) XML to TEI-conformant markup
                             <date><xsl:attribute name="when" select="format-date(current-date(), '[Y0001]-[M01]-[D01]')"/></date>
                            </resp>
                            <name>Pub2TEI XSLT [Nature_pour_bibistex.xsl]</name>
                        </respStmt>
                    </titleStmt>

                    <publicationStmt>
                        <p>this TEI version for ISTEX database (CNRS)</p>
                    </publicationStmt>

                    <!-- métadonnées décrivant l'original -->
                    <sourceDesc>
                        <biblStruct>
                            <analytic>
                                <!-- Titre article -->
                                <xsl:apply-templates select="fm/atl"/>

                                <!-- Auteurs article au+ avec leurs renvois <orf> vers l'affiliation -->
                                <xsl:apply-templates select="fm/aug"/>

                                <!-- Affiliations correspondantes
                                    /!\ interdites directement à la suite: pas conforme TEI (mais serait plus logique?)
                                        on les met plus bas dans une note type="affiliations" à la fin de ce biblStruct
                                -->

                                <!-- Identifiants article (DOI et 2 internes au groupe NPG) -->
                                <idno type="DOI"><xsl:value-of select="pubfm/doi"/></idno>
                                <idno type="npg-id"><xsl:value-of select="@id"/></idno>
                                <idno type="npg-idt"><xsl:value-of select="pubfm/idt"/></idno>
                                    <xsl:comment>source du DOI: Nature XML natif</xsl:comment>
                            </analytic>

                            <monogr>
                                <!-- Titre du périodique -->
                                <title level="j" type="full"><xsl:value-of select="pubfm/jtl"/></title>
                                
                                <!-- Identifiants journal (ISSN et eISSN) -->
                                <idno type="ISSN"><xsl:value-of select="pubfm/issn[@type='print']"/></idno>
                                <idno type="eISSN"><xsl:value-of select="pubfm/issn[@type='electronic']"/></idno>

                                <imprint>
                                    <!-- DATE -->
                                    <!-- RL: je prends l'année du copyright  -->
                                    <date type="year">
                                        <xsl:value-of select="pubfm/cpg/cpy"/>
                                    </date>
                                    
                                    <!-- VOLUME -->
                                    <biblScope unit="vol"><xsl:value-of select="pubfm/vol"/></biblScope>
                                    
                                    <!-- FASCICULE -->
                                    <biblScope unit="issue"><xsl:value-of select="pubfm/iss"/></biblScope>
                                    
                                    <!-- Pagination de l'article dans la monographie ou le fascicule -->
                                    <biblScope unit="pp">
                                        <xsl:attribute name="from" select="pubfm/pp/spn"/>
                                        <xsl:attribute name="to" select="pubfm/pp/epn"/>
                                    </biblScope>
                                </imprint>
                            </monogr>
                            
                            <!-- Adresse(s) d'affiliation: on ne peut pas les
                                mettre dans analytic à coté des auteurs alors
                                je les référence ici -->
                            <note type="affiliations" place="below">
                                <xsl:apply-templates select="fm/aug/aff | fm/aug/caff"/>
                            </note>
                        </biblStruct>
                    </sourceDesc>
                </fileDesc>


                <!-- métadonnées de profil (langue, thèmes, historique du doc) -->
                <profileDesc>
                    
                    <!-- Langue déclarée dans la balise racine -->
                    <langUsage>
                        <language>
                            <xsl:attribute name="ident" select="@language"/>
                        </language>
                    </langUsage>
                    
                    
                    <!-- mots-clefs à partir des thématiques éditoriales -->
                    <xsl:apply-templates mode="mon_kw" select="fm/atl/topic"/>
                    
                    
                    <!-- Plutot centré sur le type fonctionnel de document -->
                    <xsl:if test="pubfm/categ/categtxt | pubfm/subcateg/subcatxt">
                        <keywords scheme="npg editorial type">
                            <xsl:if test="pubfm/categ/categtxt">
                                <term><xsl:value-of select="pubfm/categ/categtxt"/></term>
                            </xsl:if>
                            <xsl:if test="pubfm/subcateg/subcatxt">
                                <term><xsl:value-of select="pubfm/subcateg/subcatxt"/></term>
                            </xsl:if>
                        </keywords>
                    </xsl:if>
                        
                    <!-- categ/@id et subcateg/@id forment aussi clairement une
                         nomenclature concernée par le type éditorial d'article
                        Ex: 'lt', 'af', 'tmln', 'rhighlts' 'forum', 'insight'... -->
                    <xsl:if test="categ/@id | subcateg/@id">
                        <textClass scheme="npg editorial type">
                            <xsl:if test="categ/@id">
                                <classCode><xsl:value-of select="fm/atl/topic"/></classCode>
                            </xsl:if>
                            <xsl:if test="subcateg/@id">
                                <classCode><xsl:value-of select="pubfm/categ/categtxt"/></classCode>
                            </xsl:if>
                        </textClass>
                    </xsl:if>                    
                </profileDesc>

                <!-- TODO ici <encodingDesc> ? -->

            </teiHeader>
            <text>
                <front>
                    <!-- résumé +/- abstract présent 1 fois sur 3 -->
                    <xsl:if test="body/fp">
                        <p>
                            <xsl:value-of select="."/>
                        </p>
                    </xsl:if>
                </front>
                <body>
                    <!-- reprise directe simpliste du body via ses sous-sous-éléments
                         TODO reprendre cette partie entièrement
                        -->
                    <xsl:for-each select="bdy/*/*">
                        <!-- BODY MASQUÉ -->
                        <p>
                            <xsl:comment>BODY MASQUÉ (/(article|headerx)/bdy/*/*)</xsl:comment>
                        </p>

                        <!-- pour afficher les fragments du body -->
                        <!--<p><xsl:value-of select='.'/></p>-->
                    </xsl:for-each>
                </body>
                <back>
                    <!-- Références bibs -->
                    <xsl:apply-templates select="/article/bm/bibl"/>
                    
                    
                    <!-- TODO bm/objects 
                              (Tables et Figures jointes à l'article)
                     -->
                    <!-- TODO Notes de bas de page ? -->
                    
                </back>
            </text>
        </TEI>
    </xsl:template>


    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        première partie de l'input :
                      ===========================
        <pubfm>   ==    PUBLICATION FRONT-MATTER 
                      ===========================
        
        Cette zone comprend les métadonnées de la publi:
          - nom de la revue et (e)ISSN
          - infos volume, fascicule
          - identifiant article
          - pagination début, fin , range
          - DOI
          - copyright (date <cpy> et owner <cpn>)
          - enfin il y a aussi des <categ> et <subcateg> 
          
          TODO => recenser les valeurs possibles pour ces categ et subcateg 
          
          ==> pas de templates car les infos sont atomiques, faciles à
              extraire en amont avec un simple value-of select="moninfo"
    -->
    
    
    

    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        deuxième partie de l'input
                ==============
        <fm> ==  FRONT-MATTER  
                ==============
        Comprend les données traditionnelles : auteur, titre
    -->

    <!-- TITRE DE L'ARTICLE ***********************
        IN: /article/fm/atl <<
        OUT: teiHeader/fileDesc/sourceDesc/biblStruct/analytic
             >> title
       
       TODO : balises de style internes: <i> <b> <super> <sup>
       
       NB: peut aussi contenir un <topic> (cf. ex2) qu'on va reprendre en ajoutant ':'
       
       ex1: <atl>Pathways in T4 morphogenesis</atl>
       ex2: <atl><topic>Astronomy</topic>Eyes wide shut</atl>
    -->
    
    <!-- topic : fournies avec le titre quand les articles 
                 sont semi-journalistiques => 2 templates 
        
        Exemples : <atl><topic>Chemistry</topic>Much binding in the lab</atl>
                               =========
              <atl><topic>Planetary science</topic>Sodium at Io</atl>
                           ===============-->
    
    <!-- Lorsqu'on l'intègre dans un titre >> on le fait suivre par un ':'  -->
    <xsl:template match="fm/atl/topic" mode="intitle"><xsl:value-of select="."/>: </xsl:template>
    
    <!-- Lorsqu'on l'utilise comme mot-clé  -->
    <xsl:template match="fm/atl/topic" mode="mon_kw">
        <keywords scheme="npg editorial theme">
            <term><xsl:value-of select="."/></term>
        </keywords>
    </xsl:template>

    <!-- FIN TITRE ARTICLE*********************** -->



    <!-- AUTEURS ***************************************
        
        Templates uniquement pour les auteurs de l'entête <fm>
        /article/header/author-group/* 
        /article/back/references//(journal-ref|book-ref|conf-ref|misc-ref)/authors
        - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        IN: /article/fm/aug/* 
        OUT: /TEI/teiHeader//sourceDesc/biblStruct  
            >> analytic/author+/*
    -->
    
    <!-- aug (groupe d'auteurs) -->
    <xsl:template match="fm/aug">
        <xsl:apply-templates select="au | cau | auname"/>
    </xsl:template>


    <!-- au
         IN: fm/aug/(au|cau)
        OUT: author/persName

    -->
    <xsl:template match="aug/au | aug/cau | aug/auname">
        <author>
            <xsl:if test="orf/@rid">
                <!-- un dièse pour corresp (renvoie ainsi à l'ID de l'affiliation) -->
                <xsl:attribute name="corresp">#<xsl:value-of select="orf/@rid"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="corf/@rid">
                <!-- idem pour variante corf -->
                <xsl:attribute name="corresp">#<xsl:value-of select="corf/@rid"/></xsl:attribute>
            </xsl:if>
            
            <persName>
                <!-- ne préjuge pas de l'ordre -->
                <xsl:apply-templates select="fnm | snm | inits"/>
            </persName>
        </author>
    </xsl:template>
    

    <!-- sous-éléments AUTEURS *************
        NB: utilisables pour les <au> du front-matter <fm> 
            et pour les <refau> des refbibs du back-matter <bm>
           ++++++++++++++++++++++++++++++++++++++++++++++++++++
        IN: << /article/fm/aug/au/*
            << /article/bm/bibl/bib/reftxt/refau/*
    -->

    <!-- nom de famille -->
    <xsl:template match="snm">
        <surname>
            <xsl:if test="../../refau">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </surname>
    </xsl:template>
    
    <!-- prénoms -->
    <xsl:template match="fnm">
        <forename>
            <xsl:if test="../../refau">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </forename>
    </xsl:template>
    
    <!-- initiales -->
    <xsl:template match="inits">
        <xsl:if test="../../refau">
            <xsl:attribute name="rend">DEL</xsl:attribute>
        </xsl:if>
        <forename full="init">
            <xsl:value-of select="."/>
        </forename>
    </xsl:template>

    <!-- suff: 'junior' etc -->
    <xsl:template match="suff">
        <genName>
            <xsl:if test="../../refau">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </genName>
    </xsl:template>

    <!-- 
        ?? pas d'équivalent tei:nameLink comme 'de', 'van der' etc 
    -->

    <!-- FIN AUTEURS *********************** -->

    <!-- ADRESSES ***********************
        IN: /article/fm/aug/(aff|caff)  <<
        OUT: /TEI/teiHeader/fileDesc/sourceDesc/biblStruct/note/.
    -->
    <xsl:template match="aug/aff | aug/caff">
        <affiliation>
            <!--Sous-éléments ID (sans contenus) >> attribut xml:id-->
            <xsl:if test="oid/@id">
                <!-- l'identifiant par affiliation (avec un corresp chez les auteurs) -->
                <xsl:attribute name="xml:id" select="oid/@id"/>
            </xsl:if>
            <xsl:if test="coid/@id">
                <!-- idem pour variante coid -->
                <xsl:attribute name="xml:id" select="coid/@id"/>
            </xsl:if>
            <address>
                <addrLine>
                    <!-- les sous-éléments avec contenus seront : org, cny (pays), cty (ville), email, etc. -->
                    <xsl:apply-templates/>
                </addrLine>
            </address>
        </affiliation>
    </xsl:template>
    
    <!--org
        OUT: <orgName>
        Ex: "Cold Spring Harbour Laboratory"
    -->
    <xsl:template match="aff/org | caff/org">
        <orgName>
            <xsl:if test="@id">
                <!--identifiant parfois observé sur les org-->
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <!--contenu-->
            <xsl:value-of select="."/>
        </orgName>
    </xsl:template>

    <!--st
        OUT: <state>
        Ex: "Belgium"
    -->
    <xsl:template match="aff/st | caff/st">
        <state>
            <xsl:value-of select="."/>
        </state>
    </xsl:template>
    
    <!--cty
        OUT: <city>
        Ex: "Paris"
    -->
    <xsl:template match="aff/cty | caff/cty">
        <settlement>
            <xsl:value-of select="."/>
        </settlement>
    </xsl:template>
    
    <!--zip
        OUT: <postCode>
        Ex: "Belgium"
    -->
    <xsl:template match="aff/zip | caff/zip">
        <postCode>
            <xsl:value-of select="."/>
        </postCode>
    </xsl:template>
    
    <!--cny
        OUT: <country>
        Ex: "Belgium"
    -->
    <xsl:template match="aff/cny | caff/cny">
        <country>
            <xsl:value-of select="."/>
        </country>
    </xsl:template>
    
    <!-- email -->
    <xsl:template match="aff/email | caff/email">
        <email>
            <xsl:apply-templates/>
        </email>
    </xsl:template>
    
    <!--
    TODO
    Autres éléments observés :
      - cty    : ville
      - zip    : CP
      - st     : état/région
      - street : rue
    -->
    
    <!-- FIN ADDR *********************** -->
    
    
    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        coeur de l'input
                 ======
        <bdy> ==  BODY  
                 ======
        IN: 
            << fp               (front)
            << p                (p)
            << sectitle         (titres sections)
            << sec              (sections)
            << figr             (figures)
            << bibr, bibrinl    (renvois citations)
            << super, sub, i    (styles)
            
        TODO : le body n'a pas **du tout** été abordé dans cette version 
        (chaque sous-sous-element est seulement juste repris directement dans des <p>)
        
        OUT >> /TEI/text/body
        NB sous la forme: */*/BODY MASQUÉ
    -->
    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        dernière partie de l'input :
        
                =============
        <bm> ==  BACK-MATTER  
                =============
        
        << bibl
        << objects
        
    -->

   
    <!--           ^^^^^^^^^^^^^^^^^
         <bibl> == références biblio
                   ^^^^^^^^^^^^^^^^^
        
        Remarque: Les refbibs balisées <reftxt> forment une ligne éditée
          (RL)    (donc avec ponctuation et ordre canonique selon un style 
                   de citation connu).
                  Elles se pretent bien à un entrainement de baliseur:
                  Comme c'est mon besoin je les convertis actuellement 
                  en <tei:bibl> et non pas en <tei:biblStruct> pour cette tache.                  
        
        
        IN <<  /article/bm/bibl
        
        OUT: TEI/text/back/div[@id="references]/listBibl
             >> tei:bibl+
                
        TODO 
          - actuellement sortie en <bibl> => passer en biblStruct ?
    -->
    
    <!-- conteneur section -->
    <xsl:template match="/article/bm/bibl">
        <div type="references">
            <listBibl>
                <xsl:apply-templates select="bib"/>
            </listBibl>
        </div>
    </xsl:template>
        
    <!-- <bib> == références structurées
                  ++++++++++++++++++++++
         IN:  /article/bm/bibl/bib
             << reftxt
        
        +++++++++++++++++++
        OUT: tei:bibl+/*
        +++++++++++++++++++
    
    Format visé en sortie: tei training bibl for grobid-train
                           => tel qu'il est décrit dans l'arbre ci-dessous
    
    Arbre tagstats du format training sur 354 fichiers, 4011 citations:
    cf. exemples sur https://github.com/kermitt2/grobid/tree/master/grobid-trainer/resources/dataset/citation/corpus    -->
    
    <!-- bib << >> tei:bibl
        
        TODO + tard pour biblStruct:
        Aiguillage possible selon les types de refbib via des tests comme :
          reftxt[jtl|vid]  ==> article de périodique
          reftxt[btl]  ==> livre ou chapitre de livre
    -->
    <xsl:template match="bib">
        <bibl type="grobid-trainerlike">
            <xsl:apply-templates/>
        </bibl>
    </xsl:template>
        
     
    <!--refbib entière dans sa forme textuelle éditée-->
    <xsl:template match="reftxt">
        <xsl:apply-templates/>
    </xsl:template>
    
    <!--sauts de lignes originels de la refbib-->
    <xsl:template match="newline">
        <lb rend="LB"/>
    </xsl:template>
    
    <!-- éléments stylistiques non utiles pour grobid-trainerlike -->
    <xsl:template match="i | b | sub | super | sc">
        <xsl:apply-templates/>
    </xsl:template>
    
    <!-- titres -->
    <xsl:template match="atl|btl|jtl">
        <title>
            <xsl:attribute name="level">
                <xsl:choose>
                    <!-- atl = article-title-->
                    <xsl:when test="name() = 'atl'">a</xsl:when>
                    
                    <!-- btl = book-title-->
                    <xsl:when test="name() = 'btl'">m</xsl:when>
                    
                    <!-- jtl = journal-title-->
                    <xsl:when test="name() = 'jtl'">j</xsl:when>
                </xsl:choose>
            </xsl:attribute>
            <xsl:apply-templates mode="intitle"/>
        </title>
    </xsl:template>
    
    <!-- cd = année -->
    <xsl:template match="cd">
        <date>        
            <xsl:apply-templates/>
        </date>
    </xsl:template>
    
    <!-- vid volume -->
    <xsl:template match="vid">
        <biblScope unit="vol">
            <xsl:apply-templates/>
        </biblScope>
    </xsl:template>
    
    <!-- iid = issue -->
    <xsl:template match="iid">
        <biblScope unit="issue">
            <xsl:apply-templates/>
        </biblScope>
    </xsl:template>
    
    <!-- refdoi = DOI -->
    <xsl:template match="refdoi">
        <idno>
            <xsl:apply-templates/>
        </idno>
    </xsl:template>
    
    <!-- url = ptr quand "titre" -->
    <xsl:template match="url">
        <ptr type="web">
            <xsl:value-of select="."/>
        </ptr>
    </xsl:template>
    
    <!-- weblink = ptr -->
    <xsl:template match="weblink">
        <ptr type="web">
            <xsl:choose>
                <!-- parfois meme valeur -->
                <xsl:when test="@url = .">
                    <xsl:value-of select="@url"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/> <xsl:value-of select="@url"/>
                </xsl:otherwise>
            </xsl:choose>
        </ptr>
    </xsl:template>
    
    <!-- natlink = ???
        ex: <natlink extrefid="00000"/><!- - 387908a0 - ->
        
        je passe ces refs mystérieuses toutes à 0 mais avec commentaire variable
    -->
    <xsl:template match="natlink"/>    
    
    <!-- refau = auteur <<<<<<<<<<<<<<<<<<<<<<  -->
    <xsl:template match="refau">
        <author rend="GRP">
            <!-- On distingue prénom (fnm) et nom (snm) mais l'entraînement 
                 bako.grobid-trainerlike() les **enlèvera** s'il travaille 
                 sur les modèles de type 'citations'.
            -->
            <xsl:apply-templates select="snm|fnm|suff"/>
        </author>
    </xsl:template>

    <!-- pagination   /!\ 2 éléments temportaires pour grobid-train et non pas tout dans
        des attributs @to et @from comme habituellement en TEI...
        En effet, dans l'entrainement, ils devront être groupés par leur tiret réel
        mais impossible en XSL de prendre spécifiquement le tiret hors balise
    -->
    
    <!-- page ppf -->
    <xsl:template match="ppf">
        <biblScope unit="pp" rend="FROM">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>
    
    <!-- page ppl -->
    <xsl:template match="ppl">
        <biblScope unit="pp" rend="PGTO">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>
    <!--
    ======== tei pre-training bibl ========  (convertissable par bako.py en trainers)

            └── bibl 4011
      X         ├── note[@rend="LB"]
                ├── lb[@rend="LB"] 326       (sauts de lignes de l'exemplaire réel) 
                ├── author[@rend="GRP"] 3551
                │   ├── surname[@rend="DEL"]
                │   ├── forename[@rend="DEL"]
                │   └── genName[@rend="DEL"]
      X         ├── editor[@rend="GRP"] 121 
                │   └─(Nature: editeurs indistincts)
                │     (ils mettent tout sous refau ou l'ignorent)
      X         ├── orgName 85
                │    └─(Nature: pas trouvé d'exemple...)
                ├── date 3994
                ├── biblScope[@unit="pp"][@rend="FROM"] 3401
                ├── biblScope[@unit="pp"][@rend="TO"] 2955
                ├── biblScope[@unit="vol"] 3076
                ├── biblScope[@unit="issue"] 323
                ├── biblScope[@unit="chapter"] 4
      X         ├── pubPlace 554 
      X         ├── publisher 302
                │    └─(Nature: publisher et pubPlace jamais annotés)
                │       (grep "\<btl\>" pour le voir)
      X         ├── note 107 
      X         ├── note[@type="report"] 76 
                │    └─(Nature: les notes **ne sont pas** annotées)
                ├── ptr[@type="web"] 13 
                ├── idno 18         
                ├── title[@level="a"] 3316
                ├── title[@level="j"] 3049
                ├── title[@level="j"][@type="short"] 2  
                ├── title[@level="m"] 662
                └── title[@level="s"] 1
    ^^^^
    non produits
    par cette feuille
    
    
    Pour obtenir un format trainers sans aucun ragréage 
    c'est possible grace au produit de cette feuille pour 2 modèles
     => pour le modèle citations
         - supprimer tous les sauts de ligne interne
         - supprimer @rend='LB et LABEL'
         - supprimer @rend='DEL'
         - grouper @rend='GRP'
         - grouper les pages ET leur délimiteur non parsé
         - remplacer @unit par @type dans les biblScope
     => pour le modèle authornames
         - ne garder que chaque groupe auteur ou éditeur
         - garder les DEL
     
     NB pour le modèle refseg ce serait aussi envisageable
         - juste LABELS si présents, et tout le reste groupé sauf rend=LB
         - mais actuellement pas alignable sur tokens...  

   ===================================
    -->


    <!-- FIN REFERENCES *********************** -->



    <!-- OBJECTS ***********************
        IN: /article/... <<
        
        OUT: /TEI/text/back
        >> div[@type="objects"]
        
        Reste à faire
    -->
    
    <!-- objects -->
    <xsl:template match="objects">
        <xsl:comment>TODO: objets liés (figures, tables)</xsl:comment>
        <div type="objects"/>
    </xsl:template>


    <!-- FIN OBJECTS *********************** -->

</xsl:stylesheet>
