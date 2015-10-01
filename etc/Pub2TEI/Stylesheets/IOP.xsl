<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" version="2.0" xmlns="http://www.tei-c.org/ns/1.0"
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">

    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>created by romain dot loth at inist.fr</xd:p>
            <xd:p>ISTEX-CNRS (déc 2014 - avril 2015)</xd:p>
        </xd:desc>
    </xd:doc>

    <xsl:output encoding="UTF-8" method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>

    <!--
        =========================
        TODO dans les entrées IOP
        =========================
          RL:
           - je ne trouve nulle part la langue
           - certains attributs en entrée sont encore ignorés 
             mais la plupart sont traités (dont notamment ids et corresp)
           - dans les titres, les éléments internes de structuration typographique sont sautés
             (italic sub sup upright inline-eqn math-text) par certains xsl:value-of
           - pour l'identification du doctype utiliser en plus le article-type/type-number ?
           
          - - - - - - - - - - - - - - - - - - - - - - - - - 
          NB: La stratégie adoptée utilise souvent des 
              apply-templates **avec select explicites**
              au lieu d'autoriser tous les sous-éléments
              
              par ex on fait:
              +++++++++++++++
                  <xsl:apply-templates select="authors 
                                             | art-title
                                             | art-number"/>
              au lieu de simplement faire:
              ++++++++++++++++++++++++++++
                  <xsl:apply-templates/>
              
              La raison en est qu'on veut initialement ne traiter 
              **que** les éléments qu'on **sait** traiter, et ignorer 
              les autres pour être certains d'avoir une maîtrise sur 
              la validité de la TEI en sortie.
              
              Pour les refbibs cela permet aussi de choisi où on met les
              auteurs selon si on aura un <analytic> ou juste un <monogr>
              
              => on ajoute au fur et à mesure les elts dans le select qui les appelle
              => à long terme si on est surs d'avoir prévu tous les cas on pourra
                 revenir partout à la notation "omnibus" <xsl:apply-templates/>
         - - - - - - - - - - - - - - - - - - - - - - - - -
         
         ARTICLE METADATA l. 229
         HEADER           l. 475
         BODY             l. 975
         BACK             l. 1509

    -->

    <!--
        ****************
        SQUELETTE GLOBAL
        ****************
        IN: /. <<

        OUT:
        /TEI/teiHeader/fileDesc/titleStmt/title >>
        /TEI/teiHeader/fileDesc/respStmt
        /TEI/teiHeader/fileDesc/sourceDesc/biblStruct >>
    -->
    <xsl:template match="/article[contains(article-metadata/article-data/copyright, 'IOP')]
                       | /article[contains(article-metadata/jnl-data/jnl-imprint, 'IOP')]
                       | /article[contains(article-metadata/jnl-data/jnl-imprint, 'Institute of Physics')]">
        <TEI>
            <teiHeader>
                <fileDesc>
                    <titleStmt>
                        <!-- Ici simplement reprise du titre principal (le détail est dans sourceDesc) -->
                        <title>
                            <xsl:value-of select="header/title-group/title"/>
                        </title>
                    </titleStmt>

                    <!-- proposition d'un "stamp" Pub2TEI -->
                    <editionStmt>
                        <respStmt>
                            <resp>
                                Conversion from IOP XML to TEI-conformant markup <date><xsl:attribute name="when" select="format-date(current-date(), '[Y0001]-[M01]-[D01]')"/></date>
                            </resp>
                            <name>Pub2TEI XSLT [IOP.xsl]</name>
                        </respStmt>
                    </editionStmt>
                    
                    <!-- mentions légales (premier jet) -->
                    <publicationStmt>
                        <publisher><xsl:value-of select="article-metadata/article-data/copyright"/></publisher>
                        <pubPlace><xsl:value-of select="article-metadata/article-data/printed"/></pubPlace>
                        <date><xsl:value-of select="article-metadata/issue-data/coverdate"/></date>
                    </publicationStmt>

                    <!-- métadonnées décrivant l'original -->
                    <sourceDesc>
                        <biblStruct>
                            <analytic>
                                <!-- Titre(s) article -->
                                <xsl:apply-templates select="header/title-group"/>

                                <!-- Auteurs article -->
                                <xsl:apply-templates select="header/author-group"/>

                                <!-- Identifiants article (DOI, PII et 3 IDS internes à IOP ...) -->
                                <xsl:apply-templates select="article-metadata/article-data/doi"/>
                                <xsl:apply-templates select="article-metadata/article-data/pii"/>
                                <xsl:apply-templates select="article-metadata/article-data/ccc"/>
                                <xsl:apply-templates
                                    select="article-metadata/article-data/article-number"/>

                                <idno type="iop-artid">
                                    <xsl:value-of select="@artid"/>
                                </idno>
                            </analytic>

                            <monogr>
                                <!-- Titres du périodique       NB: suppose un <jnl-data> ! -->
                                <xsl:apply-templates select="article-metadata/jnl-data/jnl-fullname"/>
                                <xsl:apply-templates
                                    select="article-metadata/jnl-data/jnl-abbreviation"/>
                                <xsl:apply-templates
                                    select="article-metadata/jnl-data/jnl-shortname"/>

                                <!-- Identifiants journal (ISSN et CODEN) -->
                                <xsl:apply-templates select="article-metadata/jnl-data/jnl-issn"/>
                                <xsl:apply-templates select="article-metadata/jnl-data/jnl-coden"/>

                                <imprint>
                                    <!-- VOLUMAISON -->
                                    <xsl:apply-templates
                                        select="article-metadata/volume-data/year-publication"/>
                                    <xsl:apply-templates
                                        select="article-metadata/volume-data/volume-number"/>

                                    <xsl:apply-templates
                                        select="article-metadata/issue-data/issue-number"/>
                                    <xsl:apply-templates
                                        select="article-metadata/issue-data/coverdate"/>


                                    <!-- Pagination de l'article dans la monographie ou le fascicule -->
                                    <biblScope unit="pp">
                                        <xsl:attribute name="from" select="article-metadata/article-data/first-page"/>
                                        <xsl:attribute name="to" select="article-metadata/article-data/last-page"/>
                                    </biblScope>

                                    <xsl:apply-templates
                                        select="article-metadata/article-data/length"/>

                                    <!-- Publisher jnl -->
                                    <xsl:apply-templates
                                        select="article-metadata/jnl-data/jnl-imprint"/>

                                    <!-- "printed in" ~ pubPlace -->
                                    <xsl:apply-templates
                                        select="article-metadata/article-data/printed"/>
                                </imprint>
                            </monogr>
                            
                            <!-- Adresse(s) d'affiliation: on ne peut pas les
                                 mettre dans analytic à coté des auteurs alors
                                 je les référence ici -->
                            <note type="affiliations" place="below">
                                <xsl:apply-templates select="header/address-group"/>
                            </note>
                            
                        </biblStruct>
                    </sourceDesc>
                </fileDesc>

                <!-- métadonnées de profil (thématique et historique du doc) -->
                <profileDesc>
					
                    <!-- Le résumé: abstract -->
                    <xsl:apply-templates select="header/abstract-group"/>
					
                    <!-- Reprise directe de toutes les classifications de l'article -->
                    <xsl:apply-templates select="header/classifications"/>
                    <!-- textClass ==> les classCode "pacs"
                                   ==> les subj. areas (propres à une série ?)
                                   ==> les kwds (si pas d'autre meilleur endroit)-->

                    <!-- history => creation/date+ -->
                    <xsl:apply-templates select="header/history"/>

                    <!-- Le résumé: abstract -->
                    <xsl:apply-templates select="header/abstract-group"/>
                </profileDesc>

                <!-- TODO ici <encodingDesc> ? -->

            </teiHeader>
                <text>
                    <front/>
                    <body>
                        <!-- vérif encore très stricte pour cette nouvelle feuille IOP
                             (à terme au contraire on voudra probablement un select 
                              "tout-terrain" du type select="article")
                        -->
                        <xsl:apply-templates select="/article[contains(article-metadata/article-data/copyright, 'IOP')]/body
                                                   | /article[contains(article-metadata/jnl-data/jnl-imprint, 'IOP')]/body
                                                   | /article[contains(article-metadata/jnl-data/jnl-imprint, 'Institute of Physics')]/body"/>
                    </body>
                    <back>

                        <!-- Lancement des refbibs -->
                        <xsl:apply-templates select="/article/back/references"/>
                        <!-- <listBibl> (<biblStruct/> +) </listBibl> -->


                        <!-- Notes de bas de page -->
                        <xsl:apply-templates select="/article/back/footnotes"/>
                    </back>
                </text>
        </TEI>

    </xsl:template>


    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        première partie de l'input :

        =============================
          ARTICLE-METADATA/
              [ART|ISS|VOL|JNL]-DATA
        =============================
    -->


    <!-- ARTICLE-DATA ***************************

        IN: /article/article-metadata/article-data/* <<
        La zone article-data recelle plein de trucs

        ==> templates "identifiants"
        écrivent uniquement dans header/.../analytic (d'où elles sont appelées)

        OUT:
        teiHeader/fileDesc/sourceDesc/biblStruct/analytic/.
        >> idno

    -->

    <!-- identifiant DOI-->
    <xsl:template match="article-data/doi">
        <idno type="DOI">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- identifiant PII -->
    <xsl:template match="article-data/pii">
        <idno type="PII">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- identifiant commercial IOP dit "ccc" -->
    <xsl:template match="article-data/ccc">
        <idno type="iop-ccc">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- numéro d'article IOP -->
    <xsl:template match="article-data/article-number">
        <idno type="iop-no">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>


    <!--
        Il y a aussi des imprint-like

        OUT:
        teiHeader/fileDesc/sourceDesc/biblStruct/monogr/imprint
        >> pubPlace
        >> biblScope
    -->

    <!-- printed in => pubPlace  -->
    <xsl:template match="article-data/printed">
        <pubPlace>
            <xsl:value-of select="."/>
        </pubPlace>
    </xsl:template>

    <!-- length => biblScope pp range  -->
    <xsl:template match="article-data/length">

        <!-- article-data/length (de valeur <xsl:value-of select="."/>)
            pourrait donner un biblScope unit="pp" ?  -->


    </xsl:template>

    <!-- first-page et last-page utilisés directement dans monogr -->

    <!-- FIN ARTICLE-DATA *********************** -->




    <!-- JOURNAL-DATA ***************************
        IN: /article/article-metadata/jnl-data/* <<

        OUT:
        teiHeader/fileDesc/sourceDesc/biblStruct/monogr
        >> title
        >> idno (ISSN, coden)
        >> ref (adresse web)
    -->

    <!-- full j title
         ex: "Journal of Physics D: Applied Physics" -->
    <xsl:template match="jnl-data/jnl-fullname">
        <title level="j" type="full">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <!-- abbrev j title
        ex: "J. Phys. D: Appl. Phys." -->
    <xsl:template match="jnl-data/jnl-abbreviation">
        <title level="j" type="abbrev">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <!-- short j title
        ex: "JPhysD" -->
    <xsl:template match="jnl-data/jnl-shortname">
        <title level="j" type="full">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <!-- ISSN
        ex: "0022-3727" -->
    <xsl:template match="jnl-data/jnl-issn">
        <idno type="ISSN">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- CODEN
        ex: "JPAPBE" -->
    <xsl:template match="jnl-data/jnl-coden">
        <idno type="CODEN">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- web address
        ex: "stacks.iop.org/JPhysD" -->
    <xsl:template match="jnl-data/jnl-web-address">
        <ref type="URL">
            <xsl:value-of select="."/>
        </ref>
    </xsl:template>

    <!-- imprint (~publisher)
        ex: "IOP Publishing" -->
    <xsl:template match="jnl-data/jnl-imprint">
        <publisher>
            <xsl:value-of select="."/>
        </publisher>
    </xsl:template>

    <!-- FIN JOURNAL-DATA *********************** -->



    <!-- ISSUE-DATA **************************

        IN: /article/article-metadata/issue-data/* <<

        OUT:
        teiHeader/fileDesc/sourceDesc/biblStruct/monogr/imprint
        >> biblScope
        >> date
    -->

    <!-- issue number => biblScope unit issue
        ex: "4" -->
    <xsl:template match="issue-data/issue-number">
        <biblScope unit="issue">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- coverdate => date type="cover"  ??
        ex: "April 2006" -->
    <xsl:template match="issue-data/coverdate">

        <!-- On tokenize sur les espaces -->
        <xsl:param name="segments"
            select="tokenize(.,' ')"/>
        <xsl:param name="nbSegments"
            select="count($segments)"/>

        <date type="issue-cover">
            <!-- l'attribut iso @when -->
            <xsl:attribute name="when">
                <xsl:choose>
                    <xsl:when test="$nbSegments = 3">
                        <xsl:call-template name="makeISODateFromComponents">
                            <xsl:with-param name="oldDay" select="$segments[1]"/>
                            <xsl:with-param name="oldMonth" select="$segments[2]"/>
                            <xsl:with-param name="oldYear" select="$segments[3]"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:when test="$nbSegments = 2">
                        <xsl:call-template name="makeISODateFromComponents">
                            <xsl:with-param name="oldMonth" select="$segments[1]"/>
                            <xsl:with-param name="oldYear" select="$segments[2]"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="makeISODateFromComponents">
                            <xsl:with-param name="oldYear" select="$segments[$nbSegments]"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>

            <!-- et bien sur la valeur d'origine -->
            <xsl:value-of select="."/>
        </date>
    </xsl:template>


    <!-- et VOLUME-DATA ***

        IN: /article/article-metadata/volume-data/* <<

        OUT:
        teiHeader/fileDesc/sourceDesc/biblStruct/monogr/imprint
        >> biblScope
        >> date
    -->
    <!-- volume-number
        ex: "Journal of Physics D: Applied Physics" -->
    <xsl:template match="volume-data/volume-number">
        <biblScope unit="vol">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- year-publication => année seule => date sans when
        ex: "2007" -->
    <xsl:template match="volume-data/year-publication">
        <date>
            <xsl:value-of select="."/>
        </date>
    </xsl:template>

    <!-- FIN ISSUE/VOLUME ******************** -->






    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ==============
            HEADER
        ==============
    -->

    <!-- TITRES DE L'ARTICLE ***********************
        IN: /article/header/title-group/* <<
        OUT: teiHeader/fileDesc/sourceDesc/biblStruct/analytic
             >> title
    -->
    <xsl:template match="/article/header/title-group">
        <!-- On évite de copier la balise <title-group>
            mais on doit couvrir tous les cas de figure -->
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="title-group/title">
        <title level="a" type="main">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <xsl:template match="title-group/short-title">
        <title level="a" type="short">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <xsl:template match="title-group/ej-title">
        <title level="a" type="alt" subtype="ej">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>
    <!-- FIN TITRES DE L'ARTICLE*********************** -->



    <!-- AUTEURS ***************************************

        Ces templates servent à 2 endroits : <header> et <references>
        /article/header/author-group/*
        /article/back/references//(journal-ref|book-ref|conf-ref|misc-ref)/authors
        - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        IN: author-group/*
            authors/*
            editors/*

        OUT: /TEI/teiHeader//sourceDesc/biblStruct
             /TEI/text/back//listBibl/biblStruct +

           >> analytic/author+/*
           >> analytic/editor+/*
    -->

    <!-- author-group (dans le header)
         authors (dans les références biblio)

         => deux conteneurs de liste d'auteurs, un même comportement

         TODO: (pour editors uniquement) utiliser éventuellement l'attribut optionnel @order
    -->
    <xsl:template match="header/author-group
                       | *[ends-with(local-name(),'-ref')]/authors
                       | *[ends-with(local-name(),'-ref')]/editors">
        <!-- Pas de liste en TEI, mais on remontera parfois à ce tag
             car les author IOP ne sont pas tous des author TEI,
             notamment pour les editor        -->
        <xsl:apply-templates/>
    </xsl:template>


    <!-- author | au

         IN: author-group/author (templates au-dessus)
             authors/au
             editors/author
             editors/au

        OUT: author/persName

        Cas "auteur normal"

        TODO cas si "Jr" ?
    -->
    <xsl:template match="author-group/author
                       | author-group/au
                       | authors/author
                       | authors/au">
        <author>
            <persName>
                <!-- ne préjuge pas de l'ordre -->
                <xsl:apply-templates select="./*[contains(name(),'-name')]"/>
            </persName>
            <xsl:if test="@address">
                <affiliation>
                    <xsl:attribute name="corresp" select="concat('#',@address)"/>
                </affiliation>
            </xsl:if>
        </author>
    </xsl:template>

    <!-- idem si père = editors -->
    <xsl:template match="editors/author
                       | editors/au">
        <editor>
            <persName>
                <!-- ne préjuge pas de l'ordre -->
                <xsl:apply-templates select="./*[contains(name(),'-name')]"/>
            </persName>
        </editor>
    </xsl:template>


    <!-- (Cas rares)
        IN: (authors | author-group | editors)/.
         << short-author-list
         << corporate
         << collaboration
         << collaboration/group
         << authors/others
    -->


    <!-- "les auteurs" : version "condensée conventionnellement"
        Ex: "K Rahmani et al"
        Uniquement dans la référence du header (->sourceDesc)

        TODO <author> ou <bibl> ?
    -->
    <xsl:template match="author-group/short-author-list">
        <author>
            <xsl:value-of select="."/>
        </author>
    </xsl:template>

    <!-- idem si père = editors -->
    <xsl:template match="editors/others">
        <editor>
            <xsl:value-of select="."/>
        </editor>
    </xsl:template>

    <!-- corporate
        Ex: "K Rahmani et al"

        TODO <author> ou <bibl> ?
    -->
    <xsl:template match="author-group/corporate | authors/corporate">
        <author>
            <orgName>
                <xsl:value-of select="."/>
            </orgName>
        </author>
    </xsl:template>

    <!-- idem si père = editors -->
    <xsl:template match="editors/corporate">
        <editor>
            <orgName>
                <xsl:value-of select="."/>
            </orgName>
        </editor>
    </xsl:template>

    <!--authors/collaboration
        "Collaborateur" non spécifique 
           => ne peut pas etre tei:sponsor car pas autorisé sous tei:analytic
           => ne peut pas etre tei:respStmt car on n'a pas l'explicitation d'un tei:resp dans l'input
           => TODO signaler ce manque au consortium TEI
           
        De plus respStmt n'autorise pas l' affiliation comme enfant direct, mais que au sein du name
        (pas logique non plus: le nom ne "contient" pas l'affiliation habituellement)
        
        Ex: "the ASDEX Upgrade Team"

        TODO :
          - attribut @reflist en entrée à examiner et éventuellement reprendre
    -->
    <xsl:template match="author-group/collaboration | authors/collaboration | editors/collaboration">
        <respStmt>
            
            <resp/>
            <name>
                <xsl:apply-templates/>
                <xsl:if test="@address">
                    <affiliation>
                        <xsl:attribute name="corresp" select="concat('#',@address)"/>
                    </affiliation>
                </xsl:if>
            </name>
        </respStmt>
    </xsl:template>

    <!--authors/collaboration/group
        (optionnel) le seul sous-élément autorisé de <collaboration>
        TODO voir si on peut ajouter quelque chose ici
    -->
    <xsl:template match="collaboration/group">
        <xsl:value-of select="."/>
    </xsl:template>



    <!--authors/others
        Ex: "<other><italic>et al.</italic></other>"
        Vu uniquement dans les références de fin d'article
    -->
    <xsl:template match="authors/others">
        <author ana="other-authors">
            <xsl:value-of select="normalize-space(.)"/>
        </author>
    </xsl:template>

    <!-- idem si père = editors -->
    <xsl:template match="editors/others">
        <editor ana="other-authors">
            <xsl:value-of select="normalize-space(.)"/>
        </editor>
    </xsl:template>



    <!-- sous-éléments AUTEURS *************
        NB: utilisables pour le header et pour les refbibs du <back>
            ++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        IN: << /article/header/author-group/author/*
            << /article/back/references/reference-list/*-ref/authors/au/*
    -->

    <!-- prénoms -->
    <xsl:template match="first-names">
        <!-- TODO
            tenter de séparer first-names sur espace ou point et
            générer plusieurs forename (pour chaque initiale) -->
        <forename>
            <xsl:value-of select="."/>
        </forename>
    </xsl:template>


    <!-- nom de famille -->
    <xsl:template match="second-name">
        <surname>
            <xsl:value-of select="."/>
        </surname>
    </xsl:template>



    <!-- FIN AUTEURS *********************** -->


    <!-- ADRESSES ***********************
        IN: /article/header/address-group/*  <<

        TODO : correspondances auteurs <=> adresses
    -->
    <xsl:template match="/article/header/address-group">
        <!-- 2 possibilités: adresse postale ou email -->
        <xsl:apply-templates/>
    </xsl:template>

    <!-- 1) adresse postale -->
    <xsl:template match="/article/header/address-group/address">
        <affiliation>
            <address>
                <xsl:if test="@id">
                    <!--
                        Exemple: "jpa167898ad1"
                        NB: cf. renvoi affiliation/@corresp au niveau de l'auteur
                    -->
                    <xsl:attribute name="xml:id" select="@id"/>
                </xsl:if>
                <!-- Contenus réels de l'adresse -->
                <addrLine>
                    <!--pays et/ou orgname dans une ligne "d'affiliation" plus longue-->
                    <xsl:apply-templates/>
                </addrLine>
            </address>
        </affiliation>
    </xsl:template>


    <!--      (si pays)
              IN: address-group/address/country
              OUT: ./country
              ==> rien à faire tant que apply-templates en amont
                                 et qu'il n'y pas de namespaces

              Ex: "Belgium"
    -->

    <!-- (si orgname)
             IN: <orgname>
             OUT: <orgName>
             Ex: "Laboratoire de physique des plasmas—Laboratorium voor Plasmafysica,
                  Association ‘Euratom-Etat Belge’—Associatie ‘Euratom-Belgische Staat’,
                  Ecole Royale Militaire—Koninklijke Militaire School"
    -->
    <xsl:template match="/article/header/address-group/address/orgname">
        <orgName>
            <xsl:value-of select="."/>
        </orgName>
    </xsl:template>


    <!-- 2) email : conteneur "e-adresse" -->
    <xsl:template match="e-address">
        <xsl:apply-templates/>
    </xsl:template>

    <!-- email proprement dit
        IN: address-group/e-address/email
        OUT: ./email
        Ex: "sam.gamegie@cityhall.shire"
        ==> rien à faire tant que apply-templates en amont
                            et qu'il n'y pas de namespaces
    -->

    <!-- FIN ADDR *********************** -->



    <!-- ABSTRACT ***********************
        IN: /article/header/abstract-group/*  <<

        OUT: teiHeader/profileDesc/abstract
             >> p (au lieu de head)
             >> p

        TODO passer ça dans la feuille KeywordsAbstract.xsl
        TODO vérifier si la TEI change les spécifs pour autoriser <head>
    -->

    <xsl:template match="abstract-group">
        <abstract>
            <!-- Le sous-elt heading interdit par la TEI
                 => on le transforme en <p> -->
            <p>
                <xsl:value-of select="abstract/heading"/>
            </p>
            <!-- Pour l'autre sous-elt p => pas de souci -->
            <xsl:apply-templates select="abstract/p"/>
        </abstract>
    </xsl:template>

    <!-- les templates pour <heading> et <p> sont plus bas
         dans la zone BODY -->


    <!-- FIN ABS *********************** -->



    <!-- CLASSIFICATIONS ***********************
        IN: /article/header/classifications  <<

       OUT: teiHeader/fileDesc/profileDesc/
            >> textClass/classCode
            >> textClass/keywords
            >> biblScope ?
    -->

    <!-- Déjà on met un textClass
         (car cet elt recouvre bien tous les
         contenus possibles de <classifications>) -->
    <xsl:template match="classifications">
        <textClass>
            <xsl:apply-templates/>
        </textClass>
    </xsl:template>

    <!-- class-codes ==> classCodes
       La tei a un niveau d'imbrication de moins => on plonge direct
       (mais on reviendra chercher l'attribut scheme ici)

       Ex: <class-codes scheme="pacs">
              (<code>)+
           </class-codes>
    -->
    <xsl:template match="classifications/class-codes">
        <xsl:apply-templates/>
    </xsl:template>


    <!--  IN: celui au-dessus  <<
         OUT: profileDesc/textClass
              >> classCode +
         Ex:  "52.35.Ra"
    -->
    <xsl:template match="classifications/class-codes/code">
        <classCode>
            <xsl:attribute name="scheme" select="../@scheme"/>
            <xsl:value-of select="."/>
        </classCode>
    </xsl:template>


    <!--  keywords  ==> keywords

          IN: classification  <<
         OUT: profileDesc/textClass
              >> keywords
    -->
    <xsl:template match="classifications/keywords">
        <keywords>
            <xsl:if test="@type">
                <xsl:attribute name="scheme" select="@type"/>
            </xsl:if>
            <xsl:apply-templates/>
        </keywords>
    </xsl:template>

    <!--
         IN: celui au-dessus  <<
        OUT: profileDesc/textClass/keywords
          >> term
    -->
    <xsl:template match="classifications/keywords/keyword">
        <term>
            <xsl:choose>
                <xsl:when test="@code">
                    <xsl:value-of select="@code"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </term>
    </xsl:template>


    <!-- On traite les subject-areas comme des classCode

        subject-areas ==> classCode (en enlevant une imbrication)

        IN: classification  <<
        OUT: skip inside
    -->
    <xsl:template match="classifications/subject-areas">
        <xsl:apply-templates/>
    </xsl:template>

    <!--
        IN: celui au-dessus  <<
        OUT: profileDesc/textClass
        >> classCode +
    -->
    <xsl:template match="classifications/subject-areas/category">
        <classCode>
            <xsl:attribute name="scheme" select="../@type"/>

            <xsl:choose>
                <xsl:when test="@code">
                     <xsl:value-of select="@code"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </classCode>
    </xsl:template>
    <!-- FIN CLASSIFS ************************** -->


    <!-- HISTORY ************************

        IN : /article/header/history  <<
        OUT: teiHeader/creation
             >> date +

        Ex: <history received="14 January 2010" finalform="4 March 2010" online="14 April 2010"/>

        ==> apparement cette fois tout est dans les attributs
    -->

    <xsl:template match="header/history">
        <creation>
            <xsl:for-each select="attribute::node()">
                <date>
                    <!-- TODO l'attribut iso @when -->

                    <!-- reprise du type annoncé par iop -->
                    <xsl:attribute name="type" select="name()"/>

                    <!-- reprise de valeur depuis le contenu de l'attribut -->
                    <xsl:value-of select="."/>
                </date>
            </xsl:for-each>
        </creation>

    </xsl:template>

    <!-- FIN HISTORY ******************** -->




    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ==============
            BODY
        ==============

        TODO :
          - pour l'instant seulement gestion sommaire du body (1er essai istex à ma connaissance)
             - sans attributs avancés
             - dans l'idéal il reste tout à vérifier : les sections, les <p>, les citations, l'italique, les équations, etc.
          - utiliser à terme FullTextTags.xsl
          
          
        RL: STRUCTURE de mes templates ici :
            
                      1) conteneurs / sections
                      2) paragraphes et headings
                      3) styles (italique, etc)
                      4) renvois
                      5) illustrations / figures
                      6) tables
                      7) équations
                      8) autres                      

    -->

    <xsl:template match="article/body">
        <xsl:apply-templates select="sec-level1 | acknowledgment | appendix"/>
    </xsl:template>

    <!-- CONTENEURS SEC-LEVEL[123] ***********************
        IN:  << conteneur du niveau supérieur
        OUT: >> div[@type=section]
    -->

    <!-- conteneur section niveau 1 -->
    <xsl:template match="article/body//sec-level1">
        <div type="section">
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@type != 'unnum'">
                <xsl:attribute name="n" select="@label"/>
            </xsl:if>
            <!-- Dans tous les cas 3 possibilités : head, p, sous-sec -->
            <xsl:apply-templates select="heading | p | sec-level2"/>
        </div>
    </xsl:template>

    <!-- conteneur section niveau 2 -->
    <xsl:template match="article/body//sec-level1/sec-level2">
        <div type="section">
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@type != 'unnum'">
                <xsl:attribute name="n" select="@label"/>
            </xsl:if>
            <!-- Dans tous les cas 3 possibilités : head, p, sous-sec -->
            <xsl:apply-templates select="heading | p | sec-level3"/>
        </div>
    </xsl:template>

    <!-- conteneur section niveau 3 -->
    <xsl:template match="article/body//sec-level1/sec-level2/sec-level3">
        <div type="section">
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@type != 'unnum'">
                <xsl:attribute name="n" select="@label"/>
            </xsl:if>
            <!-- Il reste 2 possibilité <head> | <p>... et très rarement <figure> -->
            <xsl:apply-templates select="heading | p"/>
        </div>
    </xsl:template>

    <!-- conteneur acknowledgment: p ou heading -->
    <xsl:template match="article/body/acknowledgment">
        <div type="ack">
            <xsl:apply-templates select="heading | p"/>
        </div>
    </xsl:template>

    <!-- conteneur appendix : mêmes contenus qu'un body -->
    <xsl:template match="article/body/appendix">
        <div type="appendix">
            <xsl:apply-templates select="sec-level1"/>
        </div>
    </xsl:template>

    <!-- ELEMENTS PRINCIPAUX ***********************
        IN:  << body/(conteneur-s)/heading
             << body/(conteneur-s)/p
             << abstract/heading
             << abstract/p
        OUT: >> head
             >> p
    -->

    <!-- heading
         template générique pour toutes les entrées body/abstract/??? -->
    <xsl:template match="heading">
        <head>
            <xsl:value-of select="normalize-space(.)"/>
        </head>
    </xsl:template>


    <!-- p
        template générique pour toutes les entrées body/abstract/??? -->
    <xsl:template match="p">
        <p>
            <!-- TODO check exhaustivité du traitement des
                templates imbriquées sous <p> par la feuille
                FullTextTags.xsl -->
            <xsl:apply-templates/>
            <!-- select="quote | cite | secref
                       | inline-eqn | table | figure
                       | sup | sub | italic | smallcap"-->
        </p>
    </xsl:template>

    <!-- SOUS-ELEMENTS DE STYLE ***********************
        IN:  << body/(conteneur-s)/p/sup | sub | italic | smallcap
        OUT: >> <hi rend="....">
    -->
    
    <!-- sup | sub | italic déjà traités dans FullTextTags.xsl -->
    
    <!-- smallcaps -->
    <xsl:template match="smallcap">
        <xsl:if test=".!=''">
            <!-- j'écris "small-caps" comme en CSS -->
            <hi rend="small-caps">
                <xsl:apply-templates/>
            </hi>
        </xsl:if>
    </xsl:template>
    
    
    <!-- SOUS-ELEMENTS références et renvois inline ***************
        IN:  << body/(conteneur-s)/secref
             << body/(conteneur-s)/figref
             << body/(conteneur-s)/tabref
             << body/(conteneur-s)/eqnref
             << body/(conteneur-s)/fnref
             << body/(conteneur-s)/cite
        
        OUT: >> ref[@type="section"]
             >> ref[@type="figure"]
             >> ref[@type="table"]
             >> ref[@type="formula"]
             >> ref[@type="footnote"]
             >> ref[@type="bib"]
             
             
          NB: l'id ou anchor vers laquelle pointe le renvoi est
              toujours notée chez IOP dans l'attribut @linkend
              En TEI j'ai mis @target partout (il y avait aussi
              l'alternative en utilisant @corresp).
    -->
    
    <xsl:template match="secref">
        <ref type="section">
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
            <xsl:value-of select="normalize-space(.)"/>
        </ref>
    </xsl:template>
    
    <xsl:template match="figref">
        <ref type="figure">
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
        </ref>
    </xsl:template>
    
    <xsl:template match="tabref">
        <ref type="table">
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
            <xsl:value-of select="normalize-space(.)"/>
        </ref>
    </xsl:template>
    
    <xsl:template match="eqnref">
        <ref type="formula">
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
            <xsl:value-of select="normalize-space(.)"/>
        </ref>
    </xsl:template>
    
    <xsl:template match="fnref">
        <ref type="noteAnchor">
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
            <xsl:value-of select="normalize-space(.)"/>
        </ref>
    </xsl:template>
    
    <xsl:template match="cite">
        <!--
            Attention "faux-ami"       
            
            iop:cite >> tei:ref     (et non pas tei:cite  /!\)
                        =======
            car tei:cite doit avoir une "quote" (alors qu'ici contenu est un label/renvoi)
            et  tei:ref est bien suggéré pour ce cas dans tei-p5-doc/fr/html/CO.html#COXR
        -->
        <ref type="bib">
            <!-- ex: #pscr370073bib4" -->
            <xsl:attribute name="target" select="concat('#',@linkend)"/>
            <!-- ex: "1" ou "4-6"  -->
            <xsl:apply-templates/>
        </ref>
    </xsl:template>


    
    <!-- SOUS-ELEMENTS ILLUSTRATIONS/FIGURES *****************
        IN:  << body/(conteneur-s)/p/figure
        OUT: >> figure
    -->
    <xsl:template match="body//figure">
        <figure>
            <xsl:attribute name="xml:id" select="@id"/>
            
            <!-- Exemple "Figure 1" dans caption/@label -->
            <xsl:if test="caption/@label">
                <!-- En TEI pas de figTitle mais un <head> possible -->
                <head>
                    <xsl:value-of select="caption/@label"/>
                </head>
            </xsl:if>
            <!-- Traitement proprement dit des sous-éléments :
                 caption ou graphic = les 2 seules possibilités -->
            <xsl:apply-templates select="caption | graphic"/>
        </figure>
    </xsl:template>

    <xsl:template match="figure/caption">
        <figDesc>
            <!-- la source contient un p avec toute sa variété -->
            <!-- la TEI n'autorise pas p avec toute sa variété -->
            <!-- => je fais value-of mais on pourrait faire comme si
                    c'était un <p> et faire apply-templates -->
            <xsl:value-of select="normalize-space(.)"/>
        </figDesc>
    </xsl:template>

    <xsl:template match="figure/graphic">
        <graphic>
            <!-- contient souvent plusieurs <graphic-file>:
                 la même image en version print ou screen)
                 Pour l'instant on n'en prend qu'une (la [1])
                 TODO prendre les autres !
            -->
            <xsl:attribute name="url" select="graphic-file[1]/@filename"/>
        </graphic>
    </xsl:template>

    <!-- SOUS-ELEMENTS table ***********************
        IN:  << body/(conteneur-s)/p/table
        OUT: >> table
             >> table
    -->
    <!-- tables -->
    <xsl:template match="body//table">
        <table>
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <!-- Exemple "Table 2" dans caption/@label -->
            <xsl:if test="caption/@label">
                <head type="table-title">
                    <xsl:value-of select="caption/@label"/>
                </head>
            </xsl:if>
            
            <!-- table: (caption?, tgroup+) -->
            <xsl:apply-templates/>
        </table>
    </xsl:template>

    <!-- on saute juste le conteneur p qui emballe toute légende
         car un tei:head a déjà un statut semblable à un <p> -->
    
    <!-- Légende de la table -->
    <xsl:template match="table/caption/p">
        <head type="table-caption">

            <xsl:apply-templates/>
        </head>
    </xsl:template>

    <!-- contenu tabulé proprement dit -->
    <xsl:template match="table/tgroup">
        <!-- les 5 éléments autorisés par IOP -->
        <xsl:apply-templates select="thead | tbody 
                                   | tfoot
                                   | colspec | spanspec"/>
    </xsl:template>
    
    
    <!-- Remarque: 
         Les tables de la source IOP vont fournir toute valeur
         classée par sections de tables : <thead> et <tbody>. 
         On décide de transposer ces classes sur l'attribut "role" du
         schéma TEI "att.tableDecoration" (c'est à dire tei:row/@role
         et tei:cell/@role).
         On transposera donc avec les valeurs "label" et "data"
         suggérées dans la doc TEI selon notre règle d'équivalence 
         suivante (un peu simpliste) :
            thead/row+ ======>> row[@role="label"]+
            tbody/row+ ======>> row[@role="data"]+
         
         TODO faire des règles d'équivalences plus précises
              par ex pour les contenus "label" typique dans la
              colonne tout à gauche: présentement mis comme "data" 
              à cause de la logique par rangées héritée du <tbody> 
    -->
    
    <!-- Première ligne -->
    <xsl:template match="table/tgroup/thead">
        <xsl:apply-templates>
            <xsl:with-param name="row-values-role" select="'label'"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Corps de la table -->
    <xsl:template match="table/tgroup/tbody">
        <xsl:apply-templates>
            <xsl:with-param name="row-values-role" select="'data'"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Pied de table :)
         /!\ ne contient pas de <row>s contrairement à thead et tbody 
             mais contient plutot des commentaires -->
    <xsl:template match="table/tgroup/tfoot">
        <trailer>
            <xsl:apply-templates/>
        </trailer>
    </xsl:template>

    <!-- style par colonnes -->
<!--    <xsl:template match="table/tgroup/colspec">
        <xsl:comment>TODO IOP table/colspec</xsl:comment>
    </xsl:template>-->

    <!-- styles des cellules groupées -->
<!--    <xsl:template match="table/tgroup/spanspec">
        <xsl:comment>TODO IOP table/spanspec</xsl:comment>
    </xsl:template>-->

    <!-- rangées avec param -->
    <xsl:template name="iop-typed-row" match="table/tgroup//row">
        <xsl:param name="row-values-role"/>
        <row>
            <xsl:attribute name="role" select="$row-values-role"/>
            <!--on passe le relais au cellules du tableau
            et on pourrait éventuellement les faire hériter
            du "role" -->
            <xsl:apply-templates/>
        </row>
    </xsl:template>

    <!-- cellules -->
    <xsl:template match="table/tgroup//entry">
        <cell>
            <xsl:value-of select="normalize-space(.)"/>
        </cell>
    </xsl:template>
    
    <!-- SOUS-ELEMENTS équations et formules ***********************
        IN:  << body/(conteneur-s)/inline-eqn
        << body/(conteneur-s)/display-eqn
        << body/(conteneur-s)/display-eqn/eqn-graphic
        << body/(conteneur-s)/eqn-group
        << body/(conteneur-s)/eqn-group/inline-eqn
        << body/(conteneur-s)/eqn-group/display-eqn
        << body/(conteneur-s)/eqn-group/display-eqn/eqn-graphic
        
        OUT: >> formula
        >> formula/graphic
        >> div/formula
        >> div/formula/graphic
    -->
    
    <!-- equations images -->
    <xsl:template match="inline-eqn[inline-graphic]
                       | display-eqn[eqn-graphic]">
        <formula>
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <graphic>
                <!-- TODO prendre aussi les attributs @format et @align -->
                <xsl:attribute name="url" select="inline-graphic/@filename | eqn-graphic/@filename"/>
            </graphic>
        </formula>
    </xsl:template>
    
    <!-- équations à notation LaTeX -->
    <xsl:template match="inline-eqn[processing-instruction(TeX)]
                       | display-eqn[processing-instruction(TeX)]">
        <formula notation="TeX">
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <!--
                RL: Je récupère directement le contenu LaTeX
                ainsi que préconisé dans doc/tei-p5-doc/fr/html/FT.html#FTFOR
            -->
            <xsl:value-of select="processing-instruction(TeX)"/>
            <!-- TODO: vérifier s'il n'y a pas d'autres contenus -->
        </formula>
    </xsl:template>
    
    <!-- TODO: il peut y avoir "les 2 à la fois"... actuellement passe en TeX
               Autrement dit, il y a des éléments <inline-eqn> ou <display-eqn>
               avec à la fois la notation LaTeX dans une instruction <?Tex?>
               et une image dans un sous-elt inline-graphic ou eqn-graphic
    -->
    
    <!-- équations à notation "math-text" 
         (markup xml linéaire très simple : italic, bold, sup, sub, upright, bold-italic) -->
    <xsl:template match="inline-eqn[math-text]">
        <xsl:if test="@id">
            <xsl:attribute name="xml:id" select="@id"/>
        </xsl:if>
        <formula notation="math-text">
            <xsl:apply-templates/>
        </formula>
    </xsl:template>
    
    <xsl:template match="math-text">
        <!-- Déjà signalé au niveau de la <formula> à la template précédente 
            ==> on passe simplement dedans
        -->
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="upright">
        <!-- Alors "upright" veut dire 'texte normal'  
             mais on va le signaler quand même pour ne rien perdre
        -->
        <hi rend="math-upright">
            <xsl:apply-templates/>
        </hi>
    </xsl:template>
    
    <!-- type d'équation inconnu -->
    <xsl:template match="inline-eqn[not(inline-graphic) and not(processing-instruction(TeX)) and not(math-text)]
                         | display-eqn[not(eqn-graphic) and not(processing-instruction(TeX))]">
        <formula notation="unknown">
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:value-of select="."/>
        </formula>
    </xsl:template>
    
    
    <!-- groupements d'équations fonctionnant ensemble
        TODO : soit permettre le div mais alors il faut sortir du tei:p ;
               soit décider comme présentement de ne pas le marquer ;
               soit trouver une autre solution.
    -->
    <xsl:template match="body//eqn-group">
        <!--<div type="eqn-group">-->
        <xsl:apply-templates/>
        <!--</div>-->
    </xsl:template>
    
    
    
    <!-- Autres SOUS-ELEMENTS BODY  ***********************
        IN:  << body/(conteneur-s)/p/*
        OUT: >> quote
             >> list/item+       
        
             TODO préserver id des listes et items ?
    -->
    
    <!-- citations inline -->
    
    <!-- même nom d'élément : à la limite on peut supprimer la template... -->
    <xsl:template match="quote">
        <quote>
            <xsl:apply-templates/>
        </quote>
    </xsl:template>
    

    <!-- 
        listes à puces
        
        remarque: le @type IOP est un style visuel
                  le @type TEI est un type logique
                  (TEI note les aspects visuels dans @rend et @style)                  
    -->
    
    <xsl:template match="body//itemized-list">
        <list rend="bulleted">
            <xsl:if test="@type != 'bullet'">
                <xsl:attribute name="style" select="@type"/>
            </xsl:if>
            <!--Contiendra des <list-item>-->
            <xsl:apply-templates/>
        </list>
    </xsl:template>
    
    <xsl:template match="body//ordered-list">
        <list rend="numbered">
            <xsl:if test="@type">
                <xsl:attribute name="style" select="@type"/>
            </xsl:if>
            <!--Contiendra des <list-item>-->
            <xsl:apply-templates/>
        </list>
    </xsl:template>
    
    <xsl:template match="body//list-item">
        <item>
            <xsl:if test="@marker">
                <xsl:attribute name="style" select="@marker"/>
            </xsl:if>
            <xsl:apply-templates/>
        </item>
    </xsl:template>
    

    <!-- FIN BODY *********************** -->



    <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        dernière partie de l'input :

        ==============
             BACK
        ==============

        < REFERENCES
        < FOOTNOTES

    -->


    <!-- ^^^^^^^^^^
         REFERENCES (biblio)
         ^^^^^^^^^^
        IN: /article/back << references

        OUT: TEI/text/back/div[@id="references]/listBibl/
        >> biblStruct +/analytic
        >> biblStruct +/monographic

       NB:  Ces 7 templates forment une structure générale qui
            appelle ensuite les sous-éléments ad hoc (plus bas)

       NB2: On place les identifiants à leur niveau pertinent (DOI article => analytic, ISBN, ISSN => monogr)
            mais les liens web ref[@url] en dehors d'analytic et monogr, comme dans l'exemple
            n° 4 (Coombs) de la doc sur www.tei-c.org/release/doc/tei-p5-doc/en/html/CO.html#COBICOL

        TODO
          - harmoniser avec Bibliography.xsl
          - idem avec JournalComponents.xsl (volume, etc)
          - l'y incorporer éventuellement
          - étudier les cas de l'attribut body/@refstyle en input
            (valeurs observées = "numeric" ou "alphabetic")
    -->

    <!-- conteneur section -->
    <xsl:template match="article/back/references">
        <div type="references">
            <xsl:apply-templates select="reference-list"/>
        </div>
    </xsl:template>

    <!-- reference-list ***********************
          IN:  article/back/references/reference-list <<
         OUT: >>listBibl
      -->
    <xsl:template match="reference-list">
        <listBibl>
            <!-- n entrées de tag parmi {journal-ref | book-ref | conf-ref | misc-ref}
                         ou cas "multipart" (imbrication gigogne de plusieurs entrées)
            -->
            <xsl:apply-templates select="multipart | ref-group | *[ends-with(local-name(),'-ref')]"/>
        </listBibl>
    </xsl:template>

    <!-- multipart | ref-group
          (cas de refbibs gigognes éventuellement récursives)
          IN:  le précédent
          OUT: listBibl
     -->
    <xsl:template match="reference-list//multipart | reference-list//ref-group">
        <!-- k entrées de tag parmi {journal-ref | book-ref | conf-ref | misc-ref} 
             ou bien de nouveau un multipart ou un ref-group récursif -->
        <xsl:apply-templates select="multipart | ref-group | *[ends-with(local-name(),'-ref')]"/>
    </xsl:template>


    <!-- références structurées
         ++++++++++++++++++++++
        IN:  article/back/references/reference-list/.
             article/back/references/reference-list/multipart//.
             article/back/references/reference-list/ref-group//.
             << journal-ref
             << book-ref
             << conf-ref
             << misc-ref

        +++++++++++++++++++
        OUT: biblStruct +/*
        +++++++++++++++++++

        TODO prise en compte des 2 attributs
             optionnels author et year-label
             *-ref/@author       ex: "Bousis et al"
             *-ref/@year-label   ex: "1963a"

             référencer la template des links autre qu'archive
             (2 cas avec que des idno multiples : SPIRES et aps)

    -->

    <!--journal-ref
        (refbib article de périodique)
    -->
    <xsl:template match="journal-ref">
        <biblStruct type="article">

            <!-- attributs courants -->
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@num">
                <xsl:attribute name="n" select="@num"/>
            </xsl:if>

            <!-- partie analytique (article) -->
            <analytic>
                <!-- utilisation pipe xpath => ne préjuge pas de l'ordre -->
                <xsl:apply-templates select="authors
                                           | art-title
                                           | art-number
                                           | preprint-info/art-number
                                           | misc-text/extdoi
                                           | crossref/cr_doi"/>
            </analytic>

            <!-- partie monographique (périodique) -->
            <monogr>
                <xsl:apply-templates select="jnl-title
                                           | conf-title
                                           | editors
                                           | crossref/cr_issn"/>
                <!-- dont imprint -->
                <imprint>
                    <xsl:apply-templates select="year
                                               | volume
                                               | part
                                               | issno
                                               | pages"/>
                </imprint>
            </monogr>
            <!-- notes et url -->
            <xsl:apply-templates select="preprint-info/preprint
                                       | misc-text[not(extdoi)]
                                       | links/arxiv"/>
        </biblStruct>
    </xsl:template>

    <!--book-ref
        (refbib livre ou chapitre de livre)
    -->
    <xsl:template match="book-ref">
        <biblStruct type="book">
            <!-- attributs courants -->
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@num">
                <xsl:attribute name="n" select="@num"/>
            </xsl:if>

            <xsl:choose>
                <!-- art-title indique que c'est un chapitre -->
                <!--Du coup les auteurs passent dans analytic (est-ce tjs valable?)-->
                <xsl:when test="art-title">
                    <analytic>
                        <xsl:apply-templates select="authors
                                                   | art-title"/>
                    </analytic>
                    <monogr>
                        <xsl:apply-templates select="book-title
                                                   | editors
                                                   | edition
                                                   | misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]"/>

                        <imprint>
                            <xsl:apply-templates select="year
                                                       | volume
                                                       | part
                                                       | chap
                                                       | pages
                                                       | publication/place
                                                       | publication/publisher"/>
                        </imprint>
                    </monogr>
                </xsl:when>

                <!-- Cas général -->
                <xsl:otherwise>
                    <monogr>
                        <xsl:apply-templates select="book-title
                                                   | authors
                                                   | editors
                                                   | edition
                                                   | misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]"/>

                        <imprint>
                            <xsl:apply-templates select="year
                                                       | volume
                                                       | part
                                                       | chap
                                                       | pages
                                                       | publication/place
                                                       | publication/publisher"/>
                        </imprint>
                    </monogr>
                </xsl:otherwise>
            </xsl:choose>

            <!-- tout le reste : série, notes, url -->
            <xsl:apply-templates select="series
                                       | preprint-info/preprint
                                       | misc-text[not(extdoi) and not(matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$'))]
                                       | links/arxiv"/>
        </biblStruct>
    </xsl:template>

    <!--conf-ref
        (refbib actes et confs)
        NB : title créé sur place à partir de conf-title et conf-place

        TODO : signaler que tei:meeting, qui serait plus intuitif pour le
               conf-title, ne peut être utilisé car si il a des contenus
               qui ressemblent à un <title>, sa sémantique tei est plus
               proche d'un <author>.
               
        TODO : extraire la date qu'on trouve parfois dans les conf-place ?
    -->
    <xsl:template match="conf-ref">
        <biblStruct type="conf">
            <!-- attributs courants -->
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@num">
                <xsl:attribute name="n" select="@num"/>
            </xsl:if>

            <analytic>
                <xsl:apply-templates select="authors
                                           | art-title"/>
            </analytic>
            <monogr>
                <!-- conf-title
                    ex: "Proc. 9th Int. Conf. on Hyperbolic Problems" -->
                <xsl:if test="conf-title | conf-place">
                    <title>
                        <xsl:value-of select="conf-title"/>
                        <xsl:if test="conf-place">
                            <!-- conf-place
                                ex: "Toulouse, 14–17 June 1999" -->
                            <placeName>
                                <xsl:value-of select="conf-place"/>
                            </placeName>
                        </xsl:if>
                    </title>
                </xsl:if>

                <xsl:apply-templates select="editors
                                           | misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]"/>
                <imprint>
                    <xsl:apply-templates select="year
                                               | volume
                                               | pages
                                               | publication/place
                                               | publication/publisher"/>
                </imprint>
            </monogr>


            <!-- tout le reste : série, notes, url -->
            <xsl:apply-templates select="series
                                       | preprint-info/preprint
                                       | misc-text[not(extdoi) and not(matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$'))]
                                       | links/arxiv"/>
        </biblStruct>
    </xsl:template>

    <!--misc-ref
        (refbib de type thèse, brevet, logiciel, lien, ...)
    -->
    <xsl:template match="misc-ref">
        <biblStruct>

            <!-- attribut type (pas aussi univoque que pour les autres ref) -->
            <xsl:attribute name="type">
                <xsl:choose>
                    <!-- test sur sous-éléments: ne pas hésiter à ajouter d'autres tests -->
                    <xsl:when test="thesis">thesis</xsl:when>
                    <xsl:when test="patent-number">patent</xsl:when>
                    
                    <!-- tests heuristiques sur (sous-)contenus texte -->                    
                    <xsl:when test="misc-text and starts-with(misc-text,'PAT')">patent</xsl:when>
                    <xsl:when test="(misc-title or misc-text) and //text()[contains(.,'Report')]">report</xsl:when>
                    
                    <!-- attribut par défaut: "misc" -->
                    <xsl:otherwise>misc</xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>

            <!-- attributs courants -->
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:if test="@num">
                <xsl:attribute name="n" select="@num"/>
            </xsl:if>

            <!-- comme pour book-ref on n'est pas toujours certains
                 d'avoir à faire un <analytic> et d'y mettre les auteurs...
                 du coup ==> test si art-title présent/absent
            -->
            <xsl:choose>
                <xsl:when test="art-title">
                    <analytic>
                        <xsl:apply-templates select="authors
                                                   | art-title"/>
                    </analytic>
                    <monogr>
                        <xsl:apply-templates select="editors
                                                   | misc-title
                                                   | edition
                                                   | patent-number
                                                   | misc-text[starts-with(normalize-space(.),'PAT')]
                                                   | misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]"/>
                        <imprint>
                            <xsl:apply-templates select="year
                                                       | volume
                                                       | pages
                                                       | publication/place
                                                       | publication/publisher
                                                       | source"/>
                        </imprint>
                    </monogr>
                </xsl:when>
                <!-- cas général -->
                <xsl:otherwise>
                    <monogr>
                        <xsl:apply-templates select="authors
                                                   | editors
                                                   | misc-title
                                                   | patent-number
                                                   | misc-text[starts-with(normalize-space(.),'PAT')]
                                                   | misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]"/>
                        <imprint>
                            <xsl:apply-templates select="year
                                                       | pages
                                                       | publication/place
                                                       | publication/publisher
                                                       | source
                                                       | edition"/>
                        </imprint>
                    </monogr>
                </xsl:otherwise>
            </xsl:choose>

            <!-- tout le reste : série, notes, url -->
            <xsl:apply-templates select="thesis
                                       | preprint-info/preprint
                                       | misc-text[not(extdoi) and not(starts-with(normalize-space(.),'PAT')) and not(matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$'))]
                                       | links/arxiv"/>


        </biblStruct>
    </xsl:template>


    <!-- SOUS-ELEMENTS BIBLIO (1/4: pour analytic) ********************

        IN:  journal-ref | book-ref | conf-ref | misc-ref
             << art-title
             << art-number
             << preprint-info/art-number
             << crossref/cr_doi

        OUT: biblStruct
             >> analytic/title[@level="a"]
             >> analytic/idno[@type="..."]
    -->

    <!-- art-title -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/art-title">
        <title level="a" type="main">
            <xsl:value-of select="normalize-space(.)"/>
        </title>
    </xsl:template>

    <!-- misc-title -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/misc-title">
        <title level="a">
            <xsl:value-of select="normalize-space(.)"/>
        </title>
    </xsl:template>

    <!-- art-number | preprint-info/art-number
         @type observé parmi jcap|jstat|jhep|arxiv (donc émis par la revue ou par un site externe)

         NB : peut se trouver directement dans *-ref ou bien (plus rare) sous preprint-info
    -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/art-number
                       | *[ends-with(local-name(),'-ref')]/preprint-info/art-number">
        <idno>
            <xsl:attribute name="type" select="@type"/>
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- misc-text/extdoi
         NB: les autres misc-text sont traités en elts <note> après monogr -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/misc-text/extdoi">
        <idno type="DOI">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- crossref/cr_doi -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/crossref/cr_doi">
        <idno type="DOI">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!--TODO     links misc-text preprint-info-->


    <!-- SOUS-ELEMENTS BIBLIO (2/4: pour monogr) *********************

        IN: journal-ref | book-ref | conf-ref | misc-ref
        <<jnl-title
        <<book-title
        <<conf-title
        <<crossref/cr_issn
        <<year
        <<volume
        <<part
        <<chap
        <<issno
        <<pages
        <<source
        <<publication/publisher
        <<publication/place
        <<edition


        NB: <<conf-title et <<conf-place traités directement dans conf-ref

        OUT: biblStruct/monogr
        >> title[@level="j"]
        >> title[@level="m"]
        >> meeting
        >> imprint/date[@type="year"]
        >> imprint/biblScope[@unit="vol"]
        >> imprint/biblScope[@unit="part"]
        >> imprint/biblScope[@unit="chap"]
        >> imprint/biblScope[@unit="issue"]
        >> imprint/biblScope[@unit="pp"]
        >> imprint/publisher
        >> imprint/pubPlace
        >> imprint/edition

    -->

    <!-- jnl-title -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/jnl-title">
        <title level="j">
            <xsl:value-of select="."/>
        </title>
    </xsl:template>

    <!-- book-title -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/book-title">
        <title level="m">
            <xsl:value-of select="."/>
            <!-- tei:meeting sous-catégorise le lieu -->
            <xsl:apply-templates select="../conf-place"/>
        </title>
    </xsl:template>

    <!-- conf-title *dans les cas rares* d'un parent journal-ref ou misc-ref
         (pour les conf-ref on ne passe pas par ici)           -->
    <xsl:template match="journal-ref/conf-title">
        <meeting>
            <xsl:value-of select="."/>
        </meeting>
    </xsl:template>

    <!--patent-number explicite
        ex: "US Patent US 2003/0116528 A1" -->
    <xsl:template match="misc-ref/patent-number">
        <idno type="docNumber">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- crossref/cr_issn -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/crossref/cr_issn">
        <idno>
            <xsl:attribute name="type">
                <xsl:choose>
                    <xsl:when test="@type='electronic'">eISSN</xsl:when>
                    <xsl:otherwise>ISSN</xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>

    <!-- misc-text/~ISBN-like~ -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/misc-text[matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$')]">
        <idno type="ISBN">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>
    
    <!-- misc-text/~PATENT-like~ -->
    <xsl:template match="misc-text[starts-with(normalize-space(.),'PAT')]">
        <idno type="PAT">
            <xsl:value-of select="."/>
        </idno>
    </xsl:template>
    
    <!-- NB: les autres misc-text sont traités en elts <note> après monogr -->

    <!--   - - - -
        >> IMPRINT
           - - - -    -->

    <!-- year
         TODO: attribut ISO @when
    -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/year">
        <date type="year">
            <xsl:value-of select="."/>
        </date>
    </xsl:template>


    <!-- volume -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/volume">
        <biblScope unit="vol">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- part   -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/part">
        <biblScope unit="part">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- chap   -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/chap">
        <biblScope unit="chap">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- issno  -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/issno">
        <biblScope unit="issue">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- pages  -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/pages">
        <biblScope unit="pp">
            <xsl:value-of select="."/>
        </biblScope>
    </xsl:template>

    <!-- source
        ex: l'université pour les thèses de doctorat
            ou le centre de recherche pour un brevet
            (se rencontre surtout dans les misc-ref)
        TODO : voir si tei:authority convient mieux que tei:publisher
    -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/source">
        <publisher>
            <xsl:value-of select="."/>
        </publisher>
    </xsl:template>

    <!-- publication/publisher -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/publication/publisher">
        <publisher>
            <xsl:value-of select="."/>
        </publisher>
    </xsl:template>

    <!-- publication/place -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/publication/place">
        <pubPlace>
            <xsl:value-of select="."/>
        </pubPlace>
    </xsl:template>

    <!--edition
        ex: "4th edn" -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/edition">
        <edition>
            <xsl:value-of select="."/>
        </edition>
    </xsl:template>


    <!-- SOUS-ELEMENTS BIBLIO (3/4: pour author+ et editor+) *****************
             +++++++++++++++++
        Déjà traités plus haut dans /article/header pour /TEI/header/sourceDesc
             +++++++++++++++++

    -->

    <!-- SOUS-ELEMENTS BIBLIO (4/4: ni analy. ni monogr.) ********************

    -->

    <!-- series | series/volume -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/series">
        <series>
            <title type="main" level="s">
                <xsl:value-of select="normalize-space(text())"/>
            </title>
            <xsl:if test="volume">
                <biblScope unit="vol">
                    <xsl:value-of select="volume"/>
                </biblScope>
            </xsl:if>
        </series>
    </xsl:template>

    <!-- misc-text

        NB: malheureusement très varié !

        Pourra devenir en TEI l'un des éléments suivants :
           - idno[@type="DOI|ISBN"]   => traités à part (ci-dessus, resp. dans analytic et dans monogr)
           - title ssi il n'y en a pas d'autre (la TEI demande un title)
           - note                     => traités ici
           - ref[@type="url"]         => traités ici

        ex: <misc-text>in preparation</misc-text>
        ex: <misc-text>at press, <extdoi doi="10.1007/s11082-009-9349-3" base="http://dx.doi.org/">doi:10.1007/s11082-009-9349-3</extdoi></misc-text>
        ex: <misc-text>ISBN 0-9586039-2-8</misc-text>
        ex: <misc-text>PAT/3.16.19/98060/98</misc-text>
        ex: <misc-text><italic>ICTP Internal Report</italic> IC/95/216</misc-text>
        ex: <misc-text>arXiv:<arxiv url="cond-mat/0408518v1">cond-mat/0408518v1</arxiv></misc-text>
        ex: <misc-text>On the fluctuating flow characteristics in the vicinity of gate slots <italic>PhD Thesis</italic> Division of Hydraulic Engineering, University of Trondheim, Norwegian Institute of Technology</misc-text>
        ex: <misc-text>(Book of abstracts 3)</misc-text>
        ex: <misc-text>OptoDesigner by PhoeniX Software <webref url="http://www.phoenixbv.com/">http://www.phoenixbv.com/</webref>
    -->
    <xsl:template name="autres_misc-text"
                  match="misc-text[
                             not(extdoi)
                         and not(matches(normalize-space(.), '^ISBN(-1[03])?\s?:?\s[-0-9xX ]{10,17}$'))
                         and not(starts-with(normalize-space(.),'PAT'))]">
        <note place="inline">
            <!-- habituellement noeuds text() ou <webref> ou <arxiv> -->
            <xsl:apply-templates/>
        </note>
    </xsl:template>

    <!-- liens inclus dans une note -->
    <xsl:template match="misc-text/webref | misc-text/arxiv | links/arxiv">
        <ref type="url">
            <xsl:if test="@url">
                <xsl:attribute name="target" select="@url"/>
            </xsl:if>
            <xsl:value-of select="."/>
        </ref>
    </xsl:template>

    <!-- preprint >> note
         NB: preprint-info/art-number déjà traité dans les templates pour analytic!
    -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/preprint-info/preprint
                       | *[ends-with(local-name(),'-ref')]/preprint">
        <note place="inline">
            <xsl:value-of select="."/>
        </note>
    </xsl:template>

    <!-- thesis >> note
         sert aussi comme test pour l'attribut ../biblStruct[@type]
    -->
    <xsl:template match="misc-ref/thesis | book-ref/thesis">
        <note place="inline">
            <xsl:value-of select="."/>
        </note>
    </xsl:template>

    <!-- links[not(arxiv)] >> | note
        ex: <links><spires jnl="GRGVA" vol="33" page="1381">SPIRES</spires></links>
        ex: <aps jnl="PRL" vol="93" page="080601" start="volume" end="pages"/>

        TODO actuellement cette template n'est pas référencée
    -->
    <xsl:template match="*[ends-with(local-name(),'-ref')]/links[not(arxiv)]">
        <note place="inline">
            <xsl:for-each select="//@*">
                <xsl:value-of select="concat( ., ' ')"/>
            </xsl:for-each>
            <xsl:value-of select="."/>
         </note>
    </xsl:template>

    <!-- FIN REFERENCES *********************** -->



    <!-- FOOTNOTES ***********************
        IN: /article/back/footnotes  <<

        OUT: /TEI/text/back/
            >> note[@place="foot"]

        TODO templates pour les styles de présentation à l'intérieur
             (p, bold, etc.) au lieu de value-of et normalize-space()
    -->

    <!-- footnotes -->
    <xsl:template match="article/back/footnotes">
        <div type="footnotes">
            <xsl:apply-templates select='footnote'/>
        </div>
    </xsl:template>

    <!-- footnote -->
    <xsl:template match="footnote">
        <note place="foot">
            <!-- id -->
            <xsl:if test="@id">
                <xsl:attribute name="xml:id" select="@id"/>
            </xsl:if>
            <xsl:value-of select="normalize-space(.)"/>
        </note>
    </xsl:template>

    <!-- FIN FOOTNOTES *********************** -->

</xsl:stylesheet>
