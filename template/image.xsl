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
img.main {
  margin-right: 1em;
  margin-top: 0.2em;
  margin-bottom: 0.2em;
}
figure {
  margin-left: 4em;
  margin-top: 2em;
}
      </style>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1><xsl:value-of select="atom:title"/></h1>
      <figure>
        <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?size=large"/>
        <figcaption style="display: inline-block; vertical-align: top">
          <xsl:call-template name="date"/>
          <xsl:apply-templates select="dc:description"/>
          <p class="exif">
            <div><xsl:value-of select="exif:camera"/></div>
            <div><xsl:value-of select="exif:lens"/></div>
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
  <div class="date"><xsl:call-template name="iso-date"/></div>
</xsl:template>

<xsl:template match="exif:date">
  <div class="date"><xsl:call-template name="exif-date"/></div>
</xsl:template>

<xsl:template match="dc:description">
  <p class="description"><xsl:value-of select="."/></p>
</xsl:template>

</xsl:stylesheet>
