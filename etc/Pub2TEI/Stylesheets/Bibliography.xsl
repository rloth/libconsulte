<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:ce="http://www.elsevier.com/xml/common/dtd"
    xmlns:mml="http://www.w3.org/1998/Math/MathML" xmlns="http://www.tei-c.org/ns/1.0"
    xmlns:sb="http://www.elsevier.com/xml/common/struct-bib/dtd" exclude-result-prefixes="#all">

    <xsl:output encoding="UTF-8" method="xml"/>

    <!-- Références bibliographiques à la fin d'un article -->
    <!-- ref-list: NLM article, ScholarOne -->

    <xsl:template match="ref-list | biblist | ce:bibliography">
        <div type="references">
            <xsl:apply-templates select="title | ce:section-title"/>
            <listBibl>
                <xsl:apply-templates select="ref | citgroup | ce:bibliography-sec"/>
            </listBibl>
        </div>
    </xsl:template>

    <xsl:template match="ce:bibliography-sec">
        <xsl:apply-templates/>
    </xsl:template>

    <!-- Références simples Elsevier -->

    <xsl:template match="ce:bib-reference[ce:other-ref]">
        <bibl xml:id="{@id}" n="{ce:label}">
            <xsl:apply-templates select="*[name()!='ce:label']"/>
        </bibl>
    </xsl:template>

    <xsl:template match="ce:other-ref">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="ce:textref">
        <xsl:apply-templates/>
    </xsl:template>

    <!-- Références complexes Elsevier -->

    <!-- Traitement des références structurées Elsevier -->
    <!--
        modifs RL:
        ==========
        3 possibilités sous <sb:host>
        
           1) sb-issue pour les périodiques       (~75% des refbibs)
           2) sb:edited-book: monogr avec editor  (~15% des refbibs)
           3) sb:book: monogr sans autre auteur   (~10% des refbibs)
           
         => J'ajoute ici les possibilités (2) et (3) auparavant absentes
            donner une info type="article" ou type="book" à la biblStruct
         
         => NB les 2 équivalences implicites
                         (sb:contribution => tei:analytic)
                      et (sb:host         => tei:monogr  )
               sont valables pour tout *sauf* titres de monographie le + souvent
               déclarés par Elsevier sous <sb:contribution>, voire plus loin sous
               sb:series, mais qui sont censés passer en TEI dans monogr...
    -->
    <xsl:template match="ce:bib-reference[sb:reference]">
            <xsl:choose>
                <!--ARTICLE DE PERIODIQUE-->
                <xsl:when test="sb:reference/sb:host/sb:issue">
                    <biblStruct xml:id="{@id}" n="{ce:label}" type="article">
                        <analytic>
                            <xsl:apply-templates select="sb:reference/sb:contribution/sb:title">
                                <xsl:with-param name="level">a</xsl:with-param>
                                <xsl:with-param name="main">vrai</xsl:with-param>
                            </xsl:apply-templates>
                            <xsl:apply-templates select="sb:reference/sb:contribution/*[name()!='sb:title']"/>
                            
                        </analytic>
                        <monogr>
                            <xsl:apply-templates select="sb:reference/sb:host/sb:issue/sb:series/sb:title"> 
                                <xsl:with-param name="level">j</xsl:with-param> 
                            </xsl:apply-templates> 
                            <imprint>
                                <!-- titre de la revue sous un sb:series qui n'a pas le même sens que tei:series -->
                                <xsl:apply-templates
                                    select="sb:reference/sb:host/sb:issue/sb:series/*[name()!='sb:title']"/>
                                <!-- date et parfois fascicule -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:issue/*[not(self::sb:series)]"/>
                                <!-- pages -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:pages/*"/>
                            </imprint>
                        </monogr>
                    </biblStruct>
                </xsl:when>
                
                <!--MONOGRAPHIE AVEC EDITEURS-->
                <xsl:when test="sb:reference/sb:host/sb:edited-book">
                    <biblStruct xml:id="{@id}" n="{ce:label}" type="book">
                        <analytic>
                            <!--ici tout <sb:contribution> sauf <sb:title> et ses fils -->
                            <xsl:apply-templates select="sb:reference/sb:contribution/*[name()!='sb:title']"/>
                            
                            <!-- Le titre restera dans analytic ssi il y en a un autre distinct dans <sb:host> -->
                            <xsl:if test="sb:reference/sb:host//sb:title">
                                <xsl:apply-templates select="sb:reference/sb:contribution/sb:title">
                                    <xsl:with-param name="level">a</xsl:with-param>
                                    <xsl:with-param name="main">vrai</xsl:with-param>
                                </xsl:apply-templates>    
                            </xsl:if>
                        </analytic>
                        <monogr>
                            <!-- titre cas 1 depuis <sb:contribution> -->
                            <xsl:if test="not(sb:reference/sb:host//sb:title)">
                                <xsl:apply-templates select="sb:reference/sb:contribution/sb:title">
                                    <xsl:with-param name="level">m</xsl:with-param>
                                    <xsl:with-param name="main">vrai</xsl:with-param>
                                </xsl:apply-templates>
                            </xsl:if>
                            
                            <!-- titre cas 2 (plus rare) titre distinct de l'analytique, 
                                 sous <sb:host> ou <sb:edited-book> -->
                            <xsl:apply-templates select="sb:reference/sb:host/sb:title
                                                       | sb:reference/sb:host/sb:edited-book/sb:title">
                                <xsl:with-param name="level">m</xsl:with-param>
                            </xsl:apply-templates>
                            
                            <!-- titre cas 3 level="m" sous sb:book-series> 
                                 si c'est le seul => ici
                                       sinon      => cf. dans tei:series derrière le monogr -->
                            <xsl:if test="sb:reference/sb:host/sb:edited-book/sb:book-series/sb:series/sb:title
                                and not(sb:reference/sb:host/sb:title or sb:reference/sb:host/sb:edited-book/sb:title)">
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:book-series/sb:series/sb:title">
                                    <xsl:with-param name="level">m</xsl:with-param>
                                </xsl:apply-templates>
                            </xsl:if>
                            
                            <!-- editors -->
                            <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:editors/*"/>
                            
                            <imprint>
                                <!-- date -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:date"/>
                                
                                <!-- publisher et pubPlace -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:publisher/*"/>
                                
                                <!-- edition ex: "2nd ed." -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:edition"/>
                                
                                <!-- conference
                                    ex: "COJFRC, Toronto., Ont. 18-21 September 1978" -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:conference"/>
                                
                                <!-- pages, directement depuis <sb:host> -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:pages/*"/>
                            </imprint>
                        </monogr>
                        
                        <!-- on a vraiment un tei:series ssi sb:book-series contient
                             autre chose qu'un titre ou que c'est juste un titre mais
                             qu'il y en a déjà eu un au niveau monogr
                                cf. le complémentaire dans cas 3 dans monogr-->
                        <xsl:if test="sb:reference/sb:host/sb:edited-book/sb:book-series
                              and (   sb:reference/sb:host/sb:edited-book/sb:book-series/sb:series/*[name()!='sb:title']
                              or sb:reference/sb:host/sb:title or sb:reference/sb:host/sb:edited-book/sb:title)">
                            <series>
                                <xsl:apply-templates select="sb:reference/sb:host/sb:edited-book/sb:book-series/sb:series/sb:title">
                                    <xsl:with-param name="level">s</xsl:with-param>
                                </xsl:apply-templates>

                                <!-- éventuellement volume etc -->
                                <xsl:apply-templates
                                    select="sb:reference/sb:host/sb:edited-book/sb:book-series/sb:series/*[name()!='sb:title']"/>
                            </series>
                        </xsl:if>
                        
                        <!-- Note diverses : TODO distinguer cas -->
                        <xsl:apply-templates select="sb:reference//sb:comment"/>
                    </biblStruct>
                </xsl:when>
                
                
                <!--
                <biblStruct type="book">
                    <xsl:apply-templates select="@id"/>
                    <monogr>
                        <!-\- All authors are included here -\->
                        <xsl:apply-templates select="$entry/person-group"/>
                        <!-\- Title information related to the paper goes here -\->
                        <xsl:apply-templates select="$entry/source"/>
                        <imprint>
                            <xsl:apply-templates select="$entry/year"/>
                            <xsl:apply-templates select="$entry/publisher-loc"/>
                            <xsl:apply-templates select="$entry/publisher-name"/>
                        </imprint>
                    </monogr>
                    <xsl:apply-templates select="$entry/pub-id"/>
                </biblStruct>
                
                -->
                
                <!--MONOGRAPHIE SIMPLE avec auteur = auteur de la contribution-->
                <xsl:when test="sb:reference/sb:host/sb:book">
                    <biblStruct xml:id="{@id}" n="{ce:label}" type="book">
                        <analytic>
                            <!--ici tout <sb:contribution> sauf <sb:title> et ses fils -->
                            <xsl:apply-templates select="sb:reference/sb:contribution/*[name()!='sb:title']"/>
                            
                            <!-- Le titre restera dans analytic ssi il y en a un autre distinct dans <sb:host> -->
                            <xsl:if test="sb:reference/sb:host//sb:title">
                                <xsl:apply-templates select="sb:reference/sb:contribution/sb:title">
                                    <xsl:with-param name="level">a</xsl:with-param>
                                    <xsl:with-param name="main">vrai</xsl:with-param>
                                </xsl:apply-templates>    
                            </xsl:if>
                        </analytic>
                        <monogr>
                            <!-- titre cas 1 depuis <sb:contribution> -->
                            <xsl:if test="not(sb:reference/sb:host//sb:title)">
                                <xsl:apply-templates select="sb:reference/sb:contribution/sb:title">
                                    <xsl:with-param name="level">m</xsl:with-param>
                                    <xsl:with-param name="main">vrai</xsl:with-param>
                                </xsl:apply-templates>
                            </xsl:if>
                            
                            <!-- titre cas 2 (plus rare) titre distinct de l'analytique, 
                                sous <sb:host> ou <sb:book> -->
                            <xsl:apply-templates select="sb:reference/sb:host/sb:title
                                                       | sb:reference/sb:host/sb:book/sb:title">
                                <xsl:with-param name="level">m</xsl:with-param>
                            </xsl:apply-templates>
                            
                            <imprint>
                                <!-- date -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:book/sb:date"/>
                                
                                <!-- publisher et pubPlace -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:book/sb:publisher/*"/>
                                
                                <!-- edition ex: "2nd ed." -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:book/sb:edition"/>
                                
                                <!-- pages, directement depuis <sb:host> -->
                                <xsl:apply-templates select="sb:reference/sb:host/sb:pages/*"/>
                            </imprint>
                        </monogr>
                        
                        <!-- Note diverses : TODO distinguer cas -->
                        <xsl:apply-templates select="sb:reference//sb:comment"/>
                    </biblStruct>
                    
                </xsl:when>
            </xsl:choose>
    </xsl:template>


    <!-- Journal paper -->

    <xsl:template match="ref[*/@citation-type='journal']">
        <xsl:call-template name="createArticle">
            <xsl:with-param name="entry" select="*[@citation-type='journal']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Journal paper in RCS -->

    <xsl:template match="citgroup">
        <xsl:call-template name="createArticle">
            <xsl:with-param name="entry" select="journalcit"/>
        </xsl:call-template>
    </xsl:template>


    <xsl:template name="createArticle">
        <xsl:param name="entry"/>
        <biblStruct type="article">
            <xsl:apply-templates select="@id"/>
            <analytic>
                <!-- All authors are included here -->
                <xsl:apply-templates select="$entry/person-group | $entry/citauth"/>
                <!-- Title information related to the paper goes here -->
                <xsl:apply-templates select="$entry/article-title"/>
            </analytic>
            <monogr>
                <xsl:apply-templates select="$entry/source | $entry/title"/>
                <imprint>
                    <xsl:apply-templates select="$entry/year"/>
                    <xsl:apply-templates select="$entry/volume | $entry/volumeno"/>
                    <xsl:apply-templates select="$entry/issue"/>
                    <xsl:apply-templates select="$entry/descendant::fpage"/>
                    <xsl:apply-templates select="$entry/descendant::lpage"/>
                </imprint>
            </monogr>
            <xsl:apply-templates select="nlm-citation/pub-id"/>
        </biblStruct>
    </xsl:template>

    <!-- Reference to a journal article (3.0 style) -->
    <xsl:template match="ref[element-citation/@publication-type='journal']">
        <xsl:call-template name="createArticle">
            <xsl:with-param name="entry" select="*[@publication-type='journal']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Conference paper - generic -->

    <xsl:template match="ref[*/@citation-type='confproc']">
        <xsl:call-template name="createInConf">
            <xsl:with-param name="entry" select="*[@citation-type='confproc']"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template name="createInConf">
        <xsl:param name="entry"/>
        <biblStruct type="inproceedings">
            <xsl:apply-templates select="@id"/>
            <analytic>
                <!-- All authors are included here -->
                <xsl:apply-templates select="$entry/person-group"/>
                <!-- Title information related to the paper goes here -->
                <xsl:apply-templates select="$entry/article-title"/>
            </analytic>
            <monogr>
                <xsl:apply-templates select="$entry/source"/>
                <xsl:apply-templates select="$entry/conf-name"/>
                <imprint>
                    <xsl:apply-templates select="$entry/year"/>
                    <xsl:apply-templates select="$entry/volume"/>
                    <xsl:apply-templates select="$entry/issue"/>
                    <xsl:apply-templates select="$entry/fpage"/>
                    <xsl:apply-templates select="$entry/lpage"/>
                </imprint>
            </monogr>
            <xsl:apply-templates select="$entry/pub-id"/>
        </biblStruct>
    </xsl:template>


    <!-- Reference to a conference paper (old style) -->
    <xsl:template match="ref[*/@citation-type='confproc']">
        <xsl:call-template name="createInConf">
            <xsl:with-param name="entry" select="*[@citation-type='confproc']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Reference to a conference paper (INSERM style!) -->
    <xsl:template match="ref[*/@citation-type='confproc']">
        <xsl:call-template name="createInConf">
            <xsl:with-param name="entry" select="*[@citation-type='confproc']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Reference to a conference paper (3.0 style) -->
    <xsl:template match="ref[*/@publication-type='confproc']">
        <xsl:call-template name="createInConf">
            <xsl:with-param name="entry" select="*[@publication-type='confproc']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Book - generic -->

    <xsl:template match="ref[*/@citation-type='book']">
        <xsl:call-template name="createBook">
            <xsl:with-param name="entry" select="*[@citation-type='book']"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Reference to a book (old style) -->

    <xsl:template match="ref[*/@publication-type='book']">
        <xsl:call-template name="createBook">
            <xsl:with-param name="entry" select="*[@publication-type='book']"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template name="createBook">
        <xsl:param name="entry"/>
        <biblStruct type="book">
            <xsl:apply-templates select="@id"/>
            <monogr>
                <!-- All authors are included here -->
                <xsl:apply-templates select="$entry/person-group"/>
                <!-- Title information related to the paper goes here -->
                <xsl:apply-templates select="$entry/source"/>
                <imprint>
                    <xsl:apply-templates select="$entry/year"/>
                    <xsl:apply-templates select="$entry/publisher-loc"/>
                    <xsl:apply-templates select="$entry/publisher-name"/>
                </imprint>
            </monogr>
            <xsl:apply-templates select="$entry/pub-id"/>
        </biblStruct>
    </xsl:template>

    <!-- Unspecified reference (old style) -->
    <xsl:template match="ref">
        <bibl>
            <xsl:apply-templates select="@id"/>
            <xsl:apply-templates select="citation"/>
        </bibl>
    </xsl:template>

    <xsl:template match="citation">
        <xsl:apply-templates/>
    </xsl:template>

    <!-- Unspecified reference (3.0 style) -->
    <xsl:template match="ref[mixed-citation]">
        <bibl>
            <xsl:apply-templates select="@id"/>
            <xsl:apply-templates select="mixed-citation"/>
        </bibl>
    </xsl:template>

    <xsl:template match="mixed-citation">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="conf-name">
        <meeting>
            <xsl:apply-templates/>
        </meeting>
    </xsl:template>

    <xsl:template match="elocation-id">
        <biblScope type="elocation-id">
            <xsl:apply-templates/>
        </biblScope>
    </xsl:template>

    <xsl:template match="person-group[@person-group-type='author']">
        <xsl:apply-templates select="name" mode="authors"/>
    </xsl:template>

    <xsl:template match="person-group[@person-group-type='editor']">
        <xsl:apply-templates mode="editors"/>
    </xsl:template>

    <xsl:template match="person-group">
        <xsl:apply-templates mode="authors"/>
    </xsl:template>

    <xsl:template match="name" mode="editors">
        <editor>
            <xsl:apply-templates select="."/>
        </editor>
    </xsl:template>

    <xsl:template match="name" mode="authors">
        <author>
            <xsl:apply-templates select="."/>
            <xsl:if test="following-sibling::*[1][name()='aff']/email">
                <xsl:apply-templates select="following-sibling::*[1][name()='aff']/email"/>
            </xsl:if>
        </author>
    </xsl:template>

    <xsl:template match="string-name | citauth">
        <author>
            <persName>
                <xsl:apply-templates/>
            </persName>
        </author>
    </xsl:template>

    <!-- Journal information for <monogr> -->
    <xsl:template match="source">
        <title level="j">
            <xsl:apply-templates/>
        </title>
    </xsl:template>

    <xsl:template match="pub-id">
        <idno>
            <xsl:attribute name="type">
                <xsl:value-of select="@pub-id-type"/>
            </xsl:attribute>
            <xsl:apply-templates/>
        </idno>
    </xsl:template>

    <!-- Generic transformation of the @id attribute -->
    <!-- If the source contains duplicated values (it does exist!) than the duplicated are renamed by order of appearance -->

    <xsl:template match="@id">
        <xsl:variable name="countIdenticalBefore">
            <xsl:value-of
                select="count(./preceding::*/@id[.=current()]) + count(./parent::*/ancestor::*/@id[.=current()])"
            />
        </xsl:variable>
        <xsl:attribute name="xml:id">
            <xsl:choose>
                <xsl:when test="$countIdenticalBefore=0">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat(.,'-',$countIdenticalBefore)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:attribute>
    </xsl:template>

    <!-- Titles -->

    <!-- Elsevier -->
    
    <!-- RL: title avec paramètre à définir pour niveau contextuel -->
    <xsl:template match="sb:title">
        <!-- éventuellement mettre une valeur par défaut: "a" pour article -->
        <xsl:param name="level"/>
        <!-- vide si faux, "vrai" si vrai -->
        <xsl:param name="main"/>
        <title>
            <xsl:attribute name="level">
                <xsl:value-of select="$level"/>
            </xsl:attribute>
            <xsl:if test="$main">
                <xsl:attribute name="type">main</xsl:attribute>
            </xsl:if>
            <!--éventuellement normalize-space()-->
            <xsl:value-of select="."/>
        </title>
    </xsl:template>
    
    <!-- RL xsl:template match="sb:maintitle"
              == supprimé et traité en amont £ == 
         Tous les sb:maintitle ne sont pas des tei:title[@type="main"]
         car pour Elsevier ça indique le principal par opposition au "short",
         ce quelquesoit le contexte (article, monogr, series), alors que pour
         la TEI c'est le titre du niveau le plus fin (article ou monogr)
         par opposition aux titres de niveau de partie    -->    

    <!-- Dates -->

    <!-- Elsevier -->
    <xsl:template match="sb:date">
        <date when="{.}">
            <xsl:apply-templates/>
        </date>
    </xsl:template>

    <!-- Authors -->

    <xsl:template match="sb:authors">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="sb:author">
        <author>
            <xsl:apply-templates/>
        </author>
    </xsl:template>


</xsl:stylesheet>
