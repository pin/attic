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
      <style>
aimg.main { margin-left: 1em }
      </style>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1 style="margin-bottom: 0.5em"><xsl:value-of select="atom:title"/></h1>
      
      <figure style="imargin: 0em;">
        <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?px=1000"/>
        <script type="text/javascript"><![CDATA[
var stdImageWidth = [300, 450, 600, 800, 1000, 1200];
YUI().use('node', function (Y) {
  var width = document.body.clientWidth;
  var w = 300;
  stdImageWidth.forEach(function(stdWidth) {
    if (width > stdWidth && stdWidth > w) {
      w = stdWidth;
    }
  });
  var src = Y.one('img.main').getAttribute('src').replace('px=1000', 'px=' + w);
  Y.one('img.main').setAttribute('src', src);
});
        ]]></script>
        <figcaption style="display: inline-block; vertical-align: top">
          <xsl:call-template name="date"/> 
        </figcaption>
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

</xsl:stylesheet>
