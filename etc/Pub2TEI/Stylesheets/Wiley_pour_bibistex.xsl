<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" version="2.0" xmlns="http://www.tei-c.org/ns/1.0"
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all"
    xmlns:wil="http://www.wiley.com/namespaces/wiley">
       
    <!--created by romain dot loth at inist.fr
                ISTEX-CNRS 2015-08-->
    <xsl:output encoding="UTF-8" method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>

    <!--
        CETTE TEMPLATE NE DEVRAIT PAS ETRE LANCEE DIRECTEMENT, 
        => PASSER PAR >> PUBLISHERS.XSL <<

        NB: entre autres défini en amont dans Publishers : le param $teiBiblType 
        'bibl' ou 'biblStruct' selon la sortie voulue (markup vs gold [déf]) 
    -->
    
    <!--
        ============================
        TODO dans les entrées WILEY
        ============================
          Actuellement on fait un header simplifié et les refbibs uniquement:
           
           - le body n'est pas fait
           
           - en mode 'bibl', on ajoute des attributs @rend qui indiquent à bako.py
             quoi faire avec, selon modèle grobid visé et on sort une <note rend="LABEL">
             quand le label est présent

      NB: les biblios sont dans le body à la fin et nativement elles  
          sont proches d'un markup <bibl> utile pour les corpus 'trainers'
          cependant en temps normal on préfèrera la sortie par défaut qui
          est 'biblStruct' <=> pour les corpus 'gold'.
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
    <xsl:template match="/wil:component[@type='serialArticle']">
        <TEI>
            <teiHeader>
                <fileDesc>
                    <titleStmt>
                        <!-- Reprise du titre principal -->
                        <title>
                            <xsl:value-of select="wil:header/wil:contentMeta/wil:titleGroup/wil:title[@type='main']"/>
                        </title>
                        <!-- proposition d'un "stamp" Pub2TEI -->
                        <respStmt>
                            <resp>Partial conversion from Wiley WML3G to TEI-conformant markup
                             <date><xsl:attribute name="when" select="format-date(current-date(), '[Y0001]-[M01]-[D01]')"/></date>
                            </resp>
                            <name>Pub2TEI XSLT [Wiley_pour_bibistex.xsl]</name>
                        </respStmt>
                    </titleStmt>

                    <publicationStmt>
                        <xsl:apply-templates
                            select="wil:header/wil:publicationMeta[@level='product']/wil:publisherInfo/wil:publisherName"/>
                        <xsl:apply-templates
                            select="wil:header/wil:publicationMeta[@level='product']/wil:publisherInfo/wil:publisherLoc"/>
                        <date>
                            <xsl:value-of
                                select="wil:header/wil:publicationMeta[@level='part']/wil:coverDate/@startDate"
                            />
                        </date>
                    </publicationStmt>

                    <!-- métadonnées décrivant l'original -->
                    <sourceDesc>
                        <biblStruct>
                            <analytic>
                                <!-- Titre article -->
                                <title level="a" type="main">
                                    <xsl:value-of
                                        select="wil:header/wil:contentMeta/wil:titleGroup/wil:title[@type='main']"
                                    />
                                </title>
                                <xsl:if
                                    test="wil:header/wil:contentMeta/wil:titleGroup/wil:title[@type='subtitle']">
                                    <title level="a" type="subtitle">
                                        <xsl:value-of
                                            select="wil:header/wil:contentMeta/wil:titleGroup/wil:title[@type='subtitle']"
                                        />
                                    </title>
                                </xsl:if>

                                <!-- Auteurs article -->
                                <xsl:apply-templates select="wil:header/wil:contentMeta/wil:creators"/>

                                <!-- Affiliations correspondantes
                                    /!\ interdites directement à la suite: pas conforme TEI (mais serait plus logique?)
                                        on les met plus bas dans une note type="affiliations" à la fin de ce biblStruct
                                -->

                                <!-- Identifiant DOI du niveau article -->
                                <xsl:if test="wil:header/wil:publicationMeta[@level='unit']/wil:doi">
                                    <idno type="DOI">
                                        <xsl:value-of
                                            select="wil:header/wil:publicationMeta[@level='unit']/wil:doi"
                                        />
                                    </idno>
                                    <xsl:comment>source du DOI: Wiley XML natif</xsl:comment>
                                </xsl:if>
                            </analytic>

                            <monogr>
                                <!-- Titres du périodique -->
                                <title level="j">
                                    <xsl:value-of
                                        select="wil:header/wil:publicationMeta[@level='product']/wil:titleGroup/wil:title[@type='main']"
                                    />
                                </title>

                                <!-- Identifiants journal -->
                                <xsl:if
                                    test="wil:header/wil:publicationMeta[@level='product']/wil:issn[@type='print']">
                                    <idno type="ISSN">
                                        <xsl:value-of
                                            select="wil:header/wil:publicationMeta[@level='product']/wil:issn[@type='print']"
                                        />
                                    </idno>
                                </xsl:if>

                                <imprint>
                                    <!-- DATE -->
                                    <!-- RL: je prends la coverDate -->
                                    <date type="year">
                                        <xsl:value-of select="wil:header/wil:publicationMeta[@level='part']/wil:coverDate"/>
                                    </date>
                                    
                                    <!-- VOLUME -->
                                    <biblScope unit="vol">
                                        <xsl:value-of
                                            select="wil:header/wil:publicationMeta[@level='part']/wil:numberingGroup/wil:numbering[@type='journalVolume']"
                                        />
                                    </biblScope>
                                    
                                    <!-- FASCICULE -->
                                    <biblScope unit="issue">
                                        <xsl:value-of
                                            select="wil:header/wil:publicationMeta[@level='part']/wil:numberingGroup/wil:numbering[@type='journalIssue']"
                                        />
                                    </biblScope>

                                    <!-- Pagination de l'article dans la monographie ou le fascicule -->
                                    <xsl:if
                                        test="wil:header/wil:publicationMeta[@level='unit']/wil:numberingGroup/wil:numbering[@type='pageFirst']">
                                        <biblScope unit="pp">
                                            <xsl:attribute name="from"
                                                select="wil:header/wil:publicationMeta[@level='unit']/wil:numberingGroup/wil:numbering[@type='pageFirst']"/>
                                            <xsl:if
                                                test="wil:header/wil:publicationMeta[@level='unit']/wil:numberingGroup/wil:numbering[@type='pageLast']">
                                                <xsl:attribute name="to"
                                                  select="wil:header/wil:publicationMeta[@level='unit']/wil:numberingGroup/wil:numbering[@type='pageLast']"
                                                />
                                            </xsl:if>
                                        </biblScope>
                                    </xsl:if>
                                </imprint>
                            </monogr>
                            <!-- Adresse(s) d'affiliation: on ne peut pas les
                                mettre dans analytic à coté des auteurs alors
                                je les référence ici -->
                            <note type="affiliations" place="below">
                                <xsl:apply-templates
                                    select="wil:header/wil:contentMeta/wil:affiliationGroup/wil:affiliation"
                                />
                            </note>
                        </biblStruct>
                    </sourceDesc>
                </fileDesc>

                <!-- métadonnées de profil (thématique et historique du doc) -->
                <profileDesc>

                    <!-- Reprise directe des keywords de l'article -->
                    <xsl:if test="wil:header/wil:contentMeta/wil:keywordGroup">
                        <textClass>
                            <keywords>
                                <xsl:for-each
                                    select="wil:header/wil:contentMeta/wil:keywordGroup/wil:keyword">
                                    <term>
                                        <xsl:value-of select="."/>
                                    </term>
                                </xsl:for-each>
                            </keywords>
                        </textClass>
                    </xsl:if>

                </profileDesc>

                <!-- TODO ici <encodingDesc> ? -->

            </teiHeader>
            <text>
                <front>

                    <!-- Le résumé wil:abstractGroup -->
                    <xsl:if test="wil:header/wil:contentMeta/wil:abstractGroup">
                        <xsl:apply-templates select="wil:header/wil:contentMeta/wil:abstractGroup"/>
                    </xsl:if>
                </front>
                <body>
                    <!-- NB: les biblios sont dans le body à la fin

                             du coup:
                              -> excepté les biblios 
                                   on affiche chaque item BODY/*/* comme de simples <p>
                              -> pour les biblios
                                   on les reprendra plus bas dans /TEI/text/back)
                        -->
                    <xsl:for-each select="wil:body/*[local-name()!='bibliography']/*">
                        <!--<p>
                            <xsl:comment>BODY MASQUÉ (/wil:component/wil:body/*/*)</xsl:comment>
                        </p>-->

                        <!-- pour afficher les segments du body -->
                        <p><xsl:value-of select='.'/></p>
                    </xsl:for-each>
                </body>
                <back>

                    <!-- ****** Lancement des biblios ****** -->
                    <xsl:apply-templates select="wil:body/wil:bibliography"/>
                    <!-- <listBibl> (bibl +) </listBibl> -->

                </back>
            </text>
        </TEI>

    </xsl:template>


    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ==============
          wil:HEADER
        ==============
        
        ici 3 templates complémentaires AUTEURS, ADRESSES, ABSTRACT
    -->


    <!-- AUTEURS ***************************************

        IN: /component/header/contentMeta/creators/*

        OUT: /TEI/teiHeader/fileDesc/sourceDesc/biblStruct/.
           >> analytic/author+/*
           >> analytic/editor+/*
        
    NB:  authorGroup (dans le header)
         authors (dans les références biblio)

         => deux conteneurs de liste d'auteurs, un même comportement ????
    -->
    <xsl:template match="wil:header/wil:contentMeta/wil:creators">
        <!-- Pas de conteneur-liste du genre authorgroup en TEI -->
        <xsl:apply-templates/>
    </xsl:template>

    <!-- creator[@creatorRole='author'] -->
    <xsl:template match="wil:creator[@creatorRole='author']">
        <author>
            <xsl:attribute name="xml:id" select="@xml:id"/>
            <persName>
                <xsl:apply-templates select="wil:personName/*"/>
                <!-- TODO ici aussi les sous-éléments wil + rares : 
                       degrees, honorifics et familyNamePrefix -->
            </persName>
            <!-- juste un pointeur tei -->
            <xsl:if test="@affiliationRef">
                <affiliation>
                    <xsl:attribute name="corresp" select="@affiliationRef"/>
                </affiliation>
            </xsl:if>
        </author>
    </xsl:template>


    <!-- sous-éléments AUTEURS *************
        IN: << /component/header/contentMeta/creators/personName/*
            << bibliography/(author|editor)
    -->

    <!-- prénoms -->
    <xsl:template match="wil:givenNames">
        <forename>
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </forename>
    </xsl:template>

    <!-- nom de famille -->
    <xsl:template match="wil:familyName">
        <surname>
            <xsl:if test="../wil:citation">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </surname>
    </xsl:template>

    <!-- nameSuffix: 'junior' etc -->
    <xsl:template match="wil:nameSuffix">
        <genName>
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </genName>
    </xsl:template>

    <!-- familyNamePrefix: 'de', 'van der' etc -->
    <xsl:template match="wil:familyNamePrefix">
        <nameLink>
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">DEL</xsl:attribute>
            </xsl:if>
            <xsl:value-of select="."/>
        </nameLink>
    </xsl:template>

    <!-- FIN AUTEURS *********************** -->


    <!-- ADRESSES ***********************
        IN: /component/header/contentMeta/affiliationGroup/affiliation  <<
        OUT: /TEI/teiHeader/fileDesc/sourceDesc/biblStruct/note/.

        Contenu des affiliations proprement dit:  Université etc.
    -->
    <xsl:template match="wil:affiliationGroup/wil:affiliation">
        <affiliation>
            <!-- l'identifiant par affiliation (avec un corresp chez les auteurs) -->
            <xsl:attribute name="xml:id" select="@xml:id"/>

            <!-- La plupart sont des unparsedAffiliation... sinon TODO: affiliation[@type='organization'] -->
            <address>
                <addrLine>
                    <xsl:value-of select="."/>
                </addrLine>
            </address>
        </affiliation>
    </xsl:template>
    <!-- FIN ADDR *********************** -->



    <!-- ABSTRACT ***********************
        IN: /component/header/contentMeta/abstractGroup  <<

        OUT: teiHeader/profileDesc/abstract
             >> p (au lieu de head)
             >> p
    -->

    <xsl:template match="wil:abstractGroup">
<!--        <abstract>-->
            <xsl:if test="wil:abstract/wil:title">
                <!-- Le sous-elt title inexistant en TEI
                    => on le transforme en <p> -->
                <p>
                    <xsl:value-of select="wil:abstract/wil:title"/>
                </p>
            </xsl:if>

            <!-- à vérifier si plusieurs p et si avec italique, listes, etc 
                  todo ==> renvoyer sur une template <p> spéciale ? -->
            <p>
                <xsl:value-of select="wil:abstract/wil:p"/>
            </p>
<!--        </abstract>-->
    </xsl:template>

    <!-- FIN ABS *********************** -->





    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        coeur de l'input
        ==========
         wil:BODY  
        ==========
        
        IN:
      << wil:body/*[local-name() != 'bibliography'] 
        
        TODO : le body n'a pas **du tout** été abordé dans cette version 
        (chaque sous-sous-element est seulement juste repris directement dans des <p>)
        
        OUT >> /TEI/text/body
    -->




    <!--
        ===========================
         wil:BODY/wil:bibliography
        ===========================
        
        Remarque: Les refbibs balisées <bib> se pretent bien à un entrainement du baliseur grobid
        Comme c'est mon besoin je les convertis actuellement en <tei:bibl> pour cette tache.                  
        
        IN << wil:body/wil:bibliography
        
        OUT: TEI/text/back/div[@id="references]/listBibl
             >> tei:bibl+
                
        TODO 
        - actuellement sortie en <bibl> => passer en biblStruct ?
        
    -->

    <!-- conteneur section -->
    <xsl:template match="wil:body/wil:bibliography">
        <div type="references">
            <!-- entête head avant la listBibl ? -->
            <p>
                <xsl:value-of select="wil:title"/>
            </p>
            <listBibl>
                <xsl:apply-templates select="wil:bib"/>
                <!-- newline après la dernière -->
                <xsl:text>&#xa;</xsl:text>
            </listBibl>
        </div>
    </xsl:template>


    <!-- conteneur:  bib = label + citation -->
    <xsl:template match="wil:bib">
        <xsl:if test="$teiBiblType = 'biblStruct'">
            <biblStruct>
                <xsl:if test="wil:label">
                    <xsl:attribute name="n">
                        <xsl:value-of select="wil:label"/>
                    </xsl:attribute>
                </xsl:if>
                <xsl:apply-templates select="wil:citation"/>
            </biblStruct>
        </xsl:if>
        
        <xsl:if test="$teiBiblType = 'bibl'">
            <bibl type="grobid-trainerlike">
                <xsl:apply-templates select="wil:label|wil:citation"/>
            </bibl>
        </xsl:if>
        
    </xsl:template>

    <!-- éléments stylistiques non utiles pour grobid-trainerlike -->
    <xsl:template match="wil:i | wil:b | wil:sub | wil:sup">
        <xsl:apply-templates/>
    </xsl:template>

    <!--^^^^^^^^^^^^^^^^^
        références biblio
        ^^^^^^^^^^^^^^^^^

        IN:  wil:bibliography/wil:citation +
                wil:citation[@type='book' and not(wil:chapterTitle)]
                wil:citation[@type='journal'] | wil:citation[@type='book' and wil:chapterTitle]
                wil:citation[@type='other']
                wil:articleTitle|wil:chapterTitle
                wil:bookTitle
                wil:otherTitle
                wil:bookSeriesTitle
                wil:pubYear
                wil:journalTitle
                wil:vol
                wil:issue
                wil:author
                wil:editor
                wil:groupName
                wil:publisherName
                wil:publisherLoc
                wil:pageFirst
                wil:pageLast
                wil:label
                wil:accessionId
                wil:edition
        
        
        OUT: tei:bibl|biblStruct+/*
        
        
        Format visé en sortie: selon xsl:param global $teiBiblType
        
        (tei_training <bibl> de grobid-trainer ou alors tei_gold <biblStruct> pour éval)
    -->

    <!-- Aiguillage - - - - - - - - - - - - - - - - - - - - - - - -
    
        Aiguillage selon les types de refbib: 
        non nécessaire pour grobid-train mais quasi IMMÉDIAT chez wiley
                                              **************
         - wil:citation[@type='journal'] => ou book avec chapterTitle
         - wil:citation[@type='book'] => sauf si chapterTitle
         - wil:citation[@type='other']
    -->

    <!-- ARTICLE et CHAPTER auraient un analytic -->
    <xsl:template match="wil:citation[@type='journal'] | wil:citation[@type='book' and wil:chapterTitle]">
        <xsl:if test="$teiBiblType = 'bibl'">
            <xsl:apply-templates/>
        </xsl:if>
        <xsl:if test="$teiBiblType = 'biblStruct'">
            <analytic>
                <xsl:apply-templates select="wil:articleTitle
                                           | wil:chapterTitle
                                           | wil:author
                                           | wil:groupName
                                           | wil:edition
                                           | wil:accessionId
                                           "/>
            </analytic>
            <monogr>
                <xsl:apply-templates select="wil:journalTitle
                                           | wil:bookTitle
                                           | wil:editor
                                           "/>
                
                <imprint>
                    <xsl:apply-templates select="wil:pubYear
                                               | wil:vol
                                               | wil:issue
                                               | wil:publisherName
                                               | wil:publisherLoc
                                               "/>
                    <xsl:if test="wil:pageFirst">
                        <biblScope unit="pp">
                            <xsl:attribute name="from">
                                <xsl:value-of select="wil:pageFirst"/>
                            </xsl:attribute>
                            <xsl:if test="wil:pageLast">
                                <xsl:attribute name="to">
                                    <xsl:value-of select="wil:pageLast"/>
                                </xsl:attribute>    
                            </xsl:if>
                        </biblScope>
                    </xsl:if>
                </imprint>
                <!-- TODO bookSeriesTitle dans series ? -->
                <xsl:apply-templates select="wil:bookSeriesTitle"/>
            </monogr>
        </xsl:if>
    </xsl:template>


    <!-- BOOKS n'auraient qu'un monogr -->
    <xsl:template match="wil:citation[@type='book' and not(wil:chapterTitle)]">
        <xsl:if test="$teiBiblType = 'bibl'">
            <xsl:apply-templates/>
        </xsl:if>
        <xsl:if test="$teiBiblType = 'biblStruct'">
            <monogr>
                <xsl:apply-templates select="wil:bookTitle
                    | wil:otherTitle
                    | wil:author
                    | wil:editor
                    | wil:groupName
                    | wil:edition
                    | wil:accessionId
                    "/>
                <imprint>
                    <xsl:apply-templates select="wil:pubYear
                        | wil:publisherName
                        | wil:publisherLoc
                        "/>
                </imprint>
                <!-- TODO bookSeriesTitle dans series ? -->
                <xsl:apply-templates select="wil:bookSeriesTitle"/>
            </monogr>
        </xsl:if>
    </xsl:template>
    

    <!-- cas spéciaux: on met un monogr polyvalent -->
    <xsl:template match="wil:citation[@type='other']">
        <xsl:if test="$teiBiblType = 'bibl'">
            <xsl:apply-templates/>
        </xsl:if>
        <xsl:if test="$teiBiblType = 'biblStruct'">
            <monogr>
                <xsl:apply-templates select="wil:bookTitle
                                            | wil:chapterTitle
                                            | wil:articleTitle
                                            | wil:journalTitle
                                            | wil:otherTitle
                                            | wil:author
                                            | wil:editor
                                            | wil:groupName
                                            | wil:edition
                                            | wil:accessionId
                    "/>
                <imprint>
                    <xsl:apply-templates select="wil:pubYear
                                        | wil:vol
                                        | wil:issue
                                        | wil:publisherName
                                        | wil:publisherLoc
                                        "/>
                    <xsl:if test="wil:pageFirst">
                        <biblScope unit="pp">
                            <xsl:attribute name="from">
                                <xsl:value-of select="wil:pageFirst"/>
                            </xsl:attribute>
                            <xsl:if test="wil:pageLast">
                                <xsl:attribute name="to">
                                    <xsl:value-of select="wil:pageLast"/>
                                </xsl:attribute>    
                            </xsl:if>
                        </biblScope>
                    </xsl:if>
                </imprint>
                <!-- TODO bookSeriesTitle dans series ? -->
                <xsl:apply-templates select="wil:bookSeriesTitle"/>
            </monogr>
        </xsl:if>
    </xsl:template>

    <!-- TITRES - - - - - - - - - - - - - - - - - - - - - -->


    <!-- titre article -->
    <xsl:template match="wil:articleTitle|wil:chapterTitle">
        <title level="a">
            <xsl:apply-templates/>
        </title>        
    </xsl:template>
        

    <!-- titre de monographie -->
    <xsl:template match="wil:bookTitle">
        <title level="m">
            <xsl:apply-templates/>
        </title>
    </xsl:template>

    <!-- titre description de la ressource -->
    <xsl:template match="wil:otherTitle">
        <title level="m" type="desc">
            <xsl:apply-templates/>
        </title>
    </xsl:template>

    <!-- titre de séries -->
    <xsl:template match="wil:bookSeriesTitle">
        <title level="s">
            <xsl:apply-templates/>
        </title>
    </xsl:template>


    <!-- année -->
    <xsl:template match="wil:pubYear">
        <date>
            <xsl:apply-templates/>
        </date>
    </xsl:template>

    <!-- titre revue -->
    <xsl:template match="wil:journalTitle">
        <title level="j">
            <xsl:apply-templates/>
        </title>
    </xsl:template>

    <!-- volume -->
    <xsl:template match="wil:vol">
        <biblScope unit="vol">
            <xsl:apply-templates/>
        </biblScope>
    </xsl:template>

    <!-- issue -->
    <xsl:template match="wil:issue">
        <biblScope unit="issue">
            <xsl:apply-templates/>
        </biblScope>
    </xsl:template>


    <!-- author et editor
        ne contiennent que des fragments de persName 
           => traités plus haut dans sous-éléments AUTEURS
           => structure wiley = même structure interne que tei:bibl/(tei:author|tei:editor) 
    -->
    <xsl:template match="wil:author">
        <author>
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">GRP</xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </author>
    </xsl:template>

    <xsl:template match="wil:editor">
        <editor>
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">GRP</xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </editor>
    </xsl:template>

    <!-- orgName -->
    <xsl:template match="wil:groupName">
        <xsl:if test="$teiBiblType = 'bibl'">
            <orgName>
                <xsl:apply-templates/>
            </orgName>
        </xsl:if>
        <xsl:if test="$teiBiblType = 'biblStruct'">
            <respStmt>
                <name>
                    <orgName>
                        <xsl:apply-templates/>
                    </orgName>
                </name>
                <resp/>
            </respStmt>
        </xsl:if>
    </xsl:template>

    <!-- publisher et pubPlace
         NB: ces 2 là sont aussi appelés au début du header -->
    <xsl:template match="wil:publisherName">
        <publisher>
            <xsl:value-of select="."/>
        </publisher>
    </xsl:template>

    <xsl:template match="wil:publisherLoc">
        <pubPlace>
            <xsl:value-of select="."/>
        </pubPlace>
    </xsl:template>

    <!-- pagination   /!\ 2 éléments temportaires seulement appelés pour grobid-train 
                            sans les attributs @to et @from comme habituellement en TEI...
                            En effet, dans l'entrainement, ils devront être groupés par leur tiret réel
                            mais impossible en XSL de prendre spécifiquement le tiret hors balise
    -->

    <!-- pageFirst -->
    <xsl:template match="wil:pageFirst">
        <biblScope unit="pp" rend="FROM">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- pageLast -->
    <xsl:template match="wil:pageLast">
        <biblScope unit="pp" rend="PGTO">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- label:
        le mapper vers un <tei:label> dans un <bibl>
        serait une entorse à la TEI mais il est très
        utile à l'apprentissage => on le garde comme note
    -->
    <xsl:template match="wil:label">
        <note rend="LABEL">
            <xsl:if test="$teiBiblType = 'bibl'">
                <xsl:attribute name="rend">LABEL</xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </note>
    </xsl:template>

    <!-- Divers *********** -->
    <xsl:template match="wil:accessionId">
        <idno type="DOI">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- edition > (monogr/)edition -->
    <xsl:template match="wil:edition">
        <edition>
            <xsl:value-of select="."/>
        </edition>
    </xsl:template>

    <!--
    ======== tei pre-training bibl ========  (convertissable par bako.py en trainers)

            └── bibl 4011 
                ├── note[@rend="LABEL"]
       X        ├── lb[@rend="LB"] 326                   (sauts de lignes de l'exemplaire réel) 
                ├── author[@rend="GRP"] 3551
                │   ├── surname[@rend="DEL"]
                │   ├── forename[@rend="DEL"]
                │   ├── genName[@rend="DEL"]
                │   └── nameLink[@rend="DEL"]
                ├── editor[@rend="GRP"] 121 
                │   ├── surname[@rend="DEL"]
                │   ├── forename[@rend="DEL"]
                │   ├── genName[@rend="DEL"]
                │   └── nameLink[@rend="DEL"]
                ├── orgName 85
                ├── date 3994
                ├── biblScope[@unit="pp"][@rend="FROM"] 3401
                ├── biblScope[@unit="pp"][@rend="TO"] 2955
                ├── biblScope[@unit="vol"] 3076
                ├── biblScope[@unit="issue"] 323
                ├── biblScope[@unit="chapter"] 4
                ├── pubPlace 554 
                ├── publisher 302 
      X         ├── note 107 
      X         ├── note[@type="report"] 76 
      X         ├── ptr[@type="web"] 13 
                ├── idno 18         
                ├── title[@level="a"] 3316
                ├── title[@level="j"] 3049
                ├── title[@level="m"] 662
                └── title[@level="s"] 1
    ^^^^
    non traités !
    dans cette feuille
   ===================================
   
    -->


    <!-- FIN REFERENCES *********************** -->

</xsl:stylesheet>
