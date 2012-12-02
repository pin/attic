<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:include href="config.xsl"/>
<xsl:include href="date.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <xsl:call-template name="common-html-head-tags"/>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
    </head>
    <body>
      <h1><xsl:value-of select="atom:title"/></h1>
      <blockquote>from <a href="{atom:link[@rel='index']/@href}"><xsl:value-of select="atom:link[@rel='index']/@title"/></a></blockquote>
      <figure style="imargin: 0em;">
        <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?px=1200" style="idisplay: inline-block; float: left; margin-bottom: 1em; margin-right: 1em"/>
        <figcaption style="idisplay: inline-block; ivertical-align: top">
          <xsl:apply-templates select="atom:updated"/>
        </figcaption>
      </figure>
    </body>
  </html>
</xsl:template>

<xsl:template match="atom:updated">
  <div class="date"><xsl:call-template name="date"/></div>
</xsl:template>

</xsl:stylesheet>
