<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:include href="config.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:call-template name="common-html-head-tags"/>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1><xsl:value-of select="atom:title"/></h1>
      <!-- <div><xsl:copy-of select="atom:content"/></div>  -->
      <div><xsl:apply-templates select="atom:content" mode="content"/></div>
    </body>
  </html>
</xsl:template>

<xsl:template match="atom:feed[atom:category/@term='directories']" mode="content">
  <ul class="directories">
    <xsl:apply-templates select="atom:entry[atom:category/@term='directory']" mode="directories"/>
  </ul>
</xsl:template>

<xsl:template match="atom:entry[atom:category/@term='directory']" mode="directories">
  <li><a href="{atom:link/@href}"><xsl:value-of select="atom:title"/></a></li>
</xsl:template>

<xsl:template match="*" mode="content">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates mode="content"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>