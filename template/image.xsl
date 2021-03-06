<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:exif="http://dp-net.com/2012/Exif"
  xmlns:dc="http://purl.org/dc/elements/1.1/">

<xsl:include href="config.xsl"/>
<xsl:include href="date.xsl"/>
<xsl:include href="replace.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <xsl:call-template name="common-html-head-tags"/>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:apply-templates select="atom:link[@rel='previous' or @rel='next' or @rel='index']" mode="head"/>
      <style type="text/css">
img.main {
  float: left
}
      </style>
      <script type="text/javascript"><![CDATA[
YUI().use('node', 'event', function (Y) {
  Y.on("domready", function() {
    Y.all("link.navigation").each(function(link) {
      if(link.get('rel') == 'next') {
        var node = Y.Node.create('<a href="' + link.get('href') + '" title="' + link.get('title') + '"><div class="next-link"></div></a>');
        Y.one("body").appendChild(node);
      }
    });
  });
});
      ]]></script>
    </head>
    <body>
      <div>
        <xsl:call-template name="top-navigatoin-bar"/>
        <h1><xsl:value-of select="atom:title"/></h1>
      </div>
      <figure>
        <div>
          <xsl:apply-templates select="atom:link[@rel='alternate' and @type='image/jpg']" mode="image-thumbnail">
            <xsl:with-param name="size" select="'large'"/>
            <xsl:with-param name="class" select="'main'"/>
            <xsl:with-param name="alt" select="atom:title"/>
          </xsl:apply-templates>
          <figcaption style="display: inline">
            <xsl:call-template name="date"/>
            <xsl:apply-templates select="dc:description"/>
            <p class="exif">
              <xsl:call-template name="exif"/>
            </p>
          </figcaption>
        </div>
        <hr width="300px" align="left" style="margin-top: 1em; clear: both"/>
        <div class="copyright-notice">&#169; 1999&#150;2013 Dmitri Popov</div>
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

<xsl:template name="exif">
  <xsl:for-each select="exif:camera/text() | exif:lens/text() | exif:film/text()">
    <xsl:call-template name="string-replace-all">
      <xsl:with-param name="text" select="."/>
      <xsl:with-param name="replace" select="' '"/>
      <xsl:with-param name="by" select="'&#160;'"/>
    </xsl:call-template>
    <xsl:if test="not(position() = last())">, </xsl:if>
  </xsl:for-each>
</xsl:template>

<xsl:template match="dc:description">
  <p class="description"><xsl:value-of select="."/></p>
</xsl:template>

</xsl:stylesheet>
