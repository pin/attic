<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:ae="http://purl.org/atom/ext/"
  xmlns:dc="http://purl.org/dc/elements/1.1/">

<xsl:include href="config.xsl"/>
<xsl:include href="date.xsl"/>

<xsl:template match="atom:feed">
  <html>
    <head>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:call-template name="common-html-head-tags"/>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1><xsl:value-of select="atom:title"/></h1>
      <div class="page-content">
        <xsl:apply-templates select="atom:entry"/>
      </div>
    </body>
  </html>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='feed']">
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='page']">
  <div class="page-content">
    <h2><a href="{atom:link/@href}"><xsl:value-of select="atom:title"/></a></h2>
    <xsl:copy-of select="atom:content"/>
  </div>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='image']">
  <div class="page-content">
    <h2><a href="{atom:link/@href}"><xsl:value-of select="atom:title"/></a></h2>
    <p><xsl:value-of select="dc:description"/></p>
    <xsl:apply-templates select="atom:link[@rel='alternate' and @type='image/jpg']" mode="image-thumbnail">
      <xsl:with-param name="size" select="'large'"/>
      <xsl:with-param name="class" select="'th'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="atom:updated"/>
  </div>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='video']">
  <div class="page-content">
    <h2><a href="{atom:link/@href}"><xsl:value-of select="atom:title"/></a></h2>
    <img class="th" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?type=image"/>
  </div>
</xsl:template>

<xsl:template match="atom:updated">
  <div class="date"><xsl:call-template name="iso-date"/></div>
</xsl:template>

</xsl:stylesheet>