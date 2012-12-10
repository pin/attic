<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:exif="http://dp-net.com/2012/Exif"
  xmlns:dc="http://purl.org/dc/elements/1.1/">

<xsl:include href="config.xsl"/>
<xsl:include href="date.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <xsl:call-template name="common-html-head-tags"/>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
      <style type="text/css">
p.exif {
  font-style: italic;
}
      </style>
    </head>
    <body>
      <div>
        <xsl:call-template name="top-navigatoin-bar"/>
        <h1><xsl:value-of select="atom:title"/></h1>
      </div>
      <figure>
        <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?size=large"/>
        <figcaption style="display: inline-block; vertical-align: top">
          <xsl:apply-templates select="dc:description"/>
          <xsl:call-template name="date"/>
          <p class="exif">
            <xsl:call-template name="exif"/>
          </p>
        </figcaption>
        <p class="copyright-notice">&#169; 1999-2012 Dmitri Popov. Please refer to the <a href="http://www.popov.org/photo/copyright.html">copyright notice</a>.</p>
      </figure>
      
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
  <p class="date"><xsl:call-template name="iso-date"/></p>
</xsl:template>
<xsl:template match="exif:date">
  <p class="date"><xsl:call-template name="exif-date"/></p>
</xsl:template>

<xsl:template name="exif">
  <xsl:for-each select="exif:camera/text() | exif:lens/text() | exif:film/text()">
    <xsl:value-of select="."/>
    <xsl:if test="not(position() = last())">, </xsl:if>
  </xsl:for-each>
</xsl:template>

<xsl:template match="dc:description">
  <div class="description"><xsl:value-of select="."/></div>
</xsl:template>

</xsl:stylesheet>
