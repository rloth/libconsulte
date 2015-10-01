<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:mml="http://www.w3.org/1998/Math/MathML"
    xmlns:ce="http://www.elsevier.com/xml/common/dtd" 
    xmlns:els="http://www.elsevier.com/xml/ja/dtd" 
    xmlns:wil="http://www.wiley.com/namespaces/wiley" 
    
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    
    <xsl:output encoding="UTF-8" method="xml"/>   
    
    <!-- VERSION MODIFIEE ISTEX AOUT 2015 -->
    
    <xsl:param name="teiBiblType" select="'biblStruct'"/>
    <!-- Remarque pour les feuilles bibistex :
        
        On a 2 choix pour la valeur du param teiBiblType
        """"""""""""""""""""""""""""""""""""""""""""""""
          "'biblStruct'" ==> structuration pour les corpus gold  (valeur par défaut)
          "'bibl'" ========> fidélité pour les corpus training
          
          
        Autrement dit: 
          
          pour les corpus refbibs gold on va toujours garder la valeur 'biblStruct'
          
          pour les corpus d'entrainement grobid [citations, authornames] => 'bibl'
                               |
                               |
                               V
          NB: pour l'entraînement il faut de plus faut enlever les newlines 
              internes à chaque bibl et faire les actions @rend (par exemple via 
              le package git.istex.fr: refbibs-stack/bib-corpus-adapt/bako.py)
    -->
    
    <xsl:include href="Imports.xsl"/>

    <xsl:include href="BMJ.xsl"/>
    <xsl:include href="NLM2TEI-article.xsl"/>
    <xsl:include href="Elsevier.xsl"/>
    <xsl:include href="ArticleSetNLMV2.0.xsl"/>
    <xsl:include href="Sage.xsl"/>
    <xsl:include href="SpringerCommon.xsl"/>
    <xsl:include href="SpringerStage2.xsl"/>
    <xsl:include href="SpringerStage3.xsl"/>
    <xsl:include href="SpringerBookChapter.xsl"/>    
    <xsl:include href="RoyalChemicalSociety.xsl"/>

    <xsl:include href="EDPSArticle.xsl"/>
    <xsl:include href="EDPSedp-article.xsl"/>
    <xsl:include href="ScholarOne.xsl"/>
    
    <!-- Modifs include RL
     pour entrainements/évals bib-istex
         ajout d'un cas Nature (sans body)
         ajout d'un cas Wiley  (sans body)
         ajout d'un cas IOP.xsl (feuille complète)
    -->
    <xsl:include href="Nature_pour_bibistex.xsl"/>
    <xsl:include href="Wiley_pour_bibistex.xsl"/>
    <xsl:include href="IOP.xsl"/>
    
    <!-- RL:
        Désactivés car ne correspondent pas au formats dans nos bases
        <xsl:include href="Nature.xsl"/>
        <xsl:include href="IOPPatch.xsl"/>
    -->
    
    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test="metadata">
                <xsl:message>XSL:Converting a BMJ article</xsl:message>
            </xsl:when>
            <xsl:when test="article_set">
                <!-- <article_set dtd_version="4.1.2"> -->
                <xsl:message>XSL:Converting a ScholarOne compatible article (e.g. OUP, Taylor,
                    Wiley)</xsl:message>
            </xsl:when>
            <xsl:when test="article[front]">
                <xsl:message>XSL:Converting an NLM 2.2 article</xsl:message>
            </xsl:when>
            <xsl:when test="els:article[els:item-info] | els:converted-article[els:item-info]">
                <xsl:message>XSL:Converting an Elsevier article</xsl:message>
            </xsl:when>
            <xsl:when test="nihms-submit">
                <xsl:message>XSL:Converting a Nature article</xsl:message>
            </xsl:when>
            <xsl:when test="ArticleSet">
                <xsl:message>XSL:Converting an NLM 2.0 article</xsl:message>
            </xsl:when>
            <xsl:when test="SAGEmeta">
                <xsl:message>XSL:Converting a Sage article</xsl:message>
            </xsl:when>
            <xsl:when test="EDPSArticle">
                <xsl:message>XSL:Converting an EDPS article</xsl:message>
            </xsl:when>
            <xsl:when test="edp-article">
                <xsl:message>XSL:Converting an EDPS backfile article</xsl:message>
            </xsl:when>
            <xsl:when test="Article/ArticleInfo">
                <xsl:message>XSL:Converting a Springer stage 2 article</xsl:message>
            </xsl:when>
            <xsl:when test="Publisher/PublisherInfo and not(Publisher/Series/Book/descendant::Chapter)">
                <xsl:message>XSL:Converting a Springer stage 3 article</xsl:message>
            </xsl:when>
            <xsl:when test="count(Publisher/Series/Book/descendant::Chapter)=1">
                <xsl:message>XSL:Converting a Springer book chapter</xsl:message>
            </xsl:when>
            <xsl:when test="article/art-admin">
                <xsl:message>XSL:Converting a Royal Chemical Society article</xsl:message>
            </xsl:when>
            
            <!-- bibistex: nouveau cas Nature -->
            <xsl:when test="starts-with(/article/pubfm/cpg/cpn, 'Nature')
                         or starts-with(/article/pubfm/cpg/cpn, 'Macmillan')
                         or starts-with(/headerx/pubfm/cpg/cpn, 'Nature')
                         or starts-with(/headerx/pubfm/cpg/cpn, 'Macmillan')">
                <xsl:message>XSL:Converting an Nature Publishing Group article</xsl:message>
            </xsl:when>
            
            <!-- bibistex: nouveau cas Wiley -->
            <xsl:when test="wil:component[@type='serialArticle']">
                <xsl:message>XSL:Converting a Wiley article</xsl:message>
            </xsl:when>
            
            <!-- générique: nouveau cas IOP -->
            <xsl:when test="(
                   contains(/article/article-metadata/article-data/copyright, 'IOP')
                or contains(/article/article-metadata/jnl-data/jnl-imprint, 'IOP')
                or contains(/article/article-metadata/jnl-data/jnl-imprint, 'Institute of Physics')
                )
                and /article/article-metadata/article-data/article-type[@sort='regular']">
                <xsl:message>XSL:Converting an IOP regular article</xsl:message>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:message>XSL:Converting a non-identified article: - name: <xsl:value-of
                        select="name(*)"/> - local-name: <xsl:value-of select="local-name(*)"/> -
                    namespace-uri: <xsl:value-of select="namespace-uri(*)"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:apply-templates/>
    </xsl:template>

</xsl:stylesheet>
