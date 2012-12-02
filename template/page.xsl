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
      <h1><xsl:value-of select="atom:title"/></h1>
      <xsl:apply-templates select="atom:link[@rel='index']"/>
      <div><xsl:copy-of select="atom:content"/></div>
    </body>
  </html>
</xsl:template>

<xsl:template match="atom:link[@rel='index']">
  <blockquote>from <a href="{@href}"><xsl:value-of select="@title"/></a></blockquote>
</xsl:template>

</xsl:stylesheet>