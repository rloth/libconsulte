<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:ce="http://www.elsevier.com/xml/common/dtd" 
    xmlns:mml="http://www.w3.org/1998/Math/MathML"
    xmlns:els="http://www.elsevier.com/xml/ja/dtd" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all">
    <xsl:output encoding="UTF-8" method="xml"/>   

    <xsl:include href="Imports.xsl"/>

    <xsl:include href="BMJ.xsl"/>
    <xsl:include href="EDPSArticle.xsl"/>
    <xsl:include href="EDPSedp-article.xsl"/>
    <xsl:include href="ScholarOne.xsl"/>
    <xsl:include href="NLM2TEI-article.xsl"/>
    <xsl:include href="Elsevier.xsl"/>
    <xsl:include href="Nature.xsl"/>
    <xsl:include href="ArticleSetNLMV2.0.xsl"/>
    <xsl:include href="Sage.xsl"/>

	<!-- RL: ajout de mon cas IOP.xsl (traite tout sauf le body) -->
    <xsl:include href="IOP.xsl"/>
    <!--
	<xsl:include href="IOPPatch.xsl"/>
    -->
    <xsl:include href="SpringerCommon.xsl"/>

    <xsl:include href="SpringerStage2.xsl"/>
    <xsl:include href="SpringerStage3.xsl"/>
    <xsl:include href="SpringerBookChapter.xsl"/>
    
    <xsl:include href="RoyalChemicalSociety.xsl"/>


    <xsl:template match="/">
        <xsl:choose>
            <xsl:when test="metadata">
                <xsl:message>Converting a BMJ article</xsl:message>
            </xsl:when>
            <xsl:when test="article_set">
                <!-- <article_set dtd_version="4.1.2"> -->
                <xsl:message>Converting a ScholarOne compatible article (e.g. OUP, Taylor,
                    Wiley)</xsl:message>
            </xsl:when>
            <xsl:when test="article[front]">
                <xsl:message>Converting an NLM 2.2 article</xsl:message>
            </xsl:when>
            <xsl:when test="els:article[els:item-info] | els:converted-article[els:item-info]">
                <xsl:message>Converting an Elsevier article</xsl:message>
            </xsl:when>
            <xsl:when test="nihms-submit">
                <xsl:message>Converting a Nature article</xsl:message>
            </xsl:when>
            <xsl:when test="ArticleSet">
                <xsl:message>Converting an NLM 2.0 article</xsl:message>
            </xsl:when>
            <xsl:when test="SAGEmeta">
                <xsl:message>Converting a Sage article</xsl:message>
            </xsl:when>
            <xsl:when test="EDPSArticle">
                <xsl:message>Converting an EDPS article</xsl:message>
            </xsl:when>
            <xsl:when test="edp-article">
                <xsl:message>Converting an EDPS backfile article</xsl:message>
            </xsl:when>
            <xsl:when test="Article/ArticleInfo">
                <xsl:message>Converting a Springer stage 2 article</xsl:message>
            </xsl:when>
            <xsl:when test="Publisher/PublisherInfo and not(Publisher/Series/Book/descendant::Chapter)">
                <xsl:message>Converting a Springer stage 3 article</xsl:message>
            </xsl:when>
            <xsl:when test="count(Publisher/Series/Book/descendant::Chapter)=1">
                <xsl:message>Converting a Springer book chapter</xsl:message>
            </xsl:when>
            <xsl:when test="article/art-admin">
                <xsl:message>Converting a Royal Chemical Society article</xsl:message>
            </xsl:when>
            <xsl:when test="tei:TEI">
                <xsl:message>Converting a TEI article into TEI (probably a damned IOP)</xsl:message>
            </xsl:when>
            
            <!-- RL: vérif encore très stricte pour le nouveau cas -->
            <xsl:when test="(
                               contains(/article/article-metadata/article-data/copyright, 'IOP')
                            or contains(/article/article-metadata/jnl-data/jnl-imprint, 'IOP')
                            or contains(/article/article-metadata/jnl-data/jnl-imprint, 'Institute of Physics')
                            )
                            and /article/article-metadata/article-data/article-type[@sort='regular']">
                <xsl:message>Converting an IOP regular article</xsl:message>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:message>Converting a non-identified article: - name: <xsl:value-of
                        select="name(*)"/> - local-name: <xsl:value-of select="local-name(*)"/> -
                    namespace-uri: <xsl:value-of select="namespace-uri(*)"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:apply-templates/>
    </xsl:template>

</xsl:stylesheet>
