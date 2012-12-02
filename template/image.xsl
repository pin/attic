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
      <script src="http://yui.yahooapis.com/3.7.3/build/yui/yui-min.js"></script>
      <script><![CDATA[
YUI().use('node', 'event', function (Y) {
  Y.on("domready", function (e) {
    //var navigation = Y.Node.create("<div class='navigation'/>");
    Y.all('html head link.navigation').each(function(link) {
       var rel = link.getAttribute('rel');
       var href = link.getAttribute('href');
       var tile = Y.Node.create("<div class='navigation'><a><div class='tile bg-color-blueDark'><div class='tile-content'></div></div></a></div>");
       tile.one('div.tile-content').append('<h2>' + rel + '</h2>');
       tile.one('a').setAttribute('href', href);
       if (rel == 'previous') {
         tile.one('div.tile').addClass('icon-arrow-left');
       }
       if (rel == 'index') {
         tile.one('div.tile').addClass('icon-grid-view');
       }
       if (rel == 'next') {
         tile.one('div.tile').addClass('icon-arrow-right');
       }
       Y.one('html body').prepend(tile);
       //navigation.append(tile); 
    });
    //Y.one('html body').prepend(navigation);
  });  
});
      ]]></script>
      <style>
div.navigation {
    float: right;
}
      </style>
    </head>
    <body>
      <h1><xsl:value-of select="atom:title"/></h1>
<!--  <blockquote>from <a href="{atom:link[@rel='index']/@href}"><xsl:value-of select="atom:link[@rel='index']/@title"/></a></blockquote>  -->
      <figure style="imargin: 0em;">
        <img class="main" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?px=1200" style="idisplay: inline-block; float: left; margin-bottom: 1em; margin-right: 1em"/>
        <figcaption style="idisplay: inline-block; ivertical-align: top">
          <!-- <xsl:call-template name="date"/>  --> 
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
