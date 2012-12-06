<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:exif="http://dp-net.com/2012/Exif">

<xsl:include href="config.xsl"/>
<xsl:include href="date.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <xsl:call-template name="common-html-head-tags"/>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
      <style type="text/css">
img.main {
  margin-right: 0.2em;
  margin-top: 0.2em;
  margin-bottom: 0.2em;
}
      </style>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <div class="page">
        <h2><xsl:value-of select="atom:title"/></h2>
        <figure style="display: block;   margin-left: auto;   margin-right: auto;">
          <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?size=large"/>
          <figcaption style="display: inline-block; vertical-align: top">
            <p><xsl:call-template name="date"/></p>
            <div><xsl:value-of select="exif:camera"/></div>
            <div><xsl:value-of select="exif:lens"/></div>
          </figcaption>
        </figure>
      </div>
    </body>
  </html>
</xsl:template>

<xsl:template name="date">
  <xsl:choose>
    <xsl:when test="exif:date">
      <xsl:apply-templates select="exif:date"/>
    </xsl:when>
    <xsl:when test="atom:updated">
      <xsl:apply-templates select="atom:updated"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="atom:updated">
  <div class="date"><xsl:call-template name="iso-date"/></div>
</xsl:template>

<xsl:template match="exif:date">
  <div class="date"><xsl:call-template name="exif-date"/></div>
</xsl:template>

</xsl:stylesheet>
