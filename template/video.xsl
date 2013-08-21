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
      <div style="margin-top: 2em">
        <center>
          <video controls="on" preload="auto" width="854" height="480" data-setup="">
            <source src="{atom:link[@rel='alternate' and @type='video/mp4']/@href}" type='video/mp4'/>
          </video>
        </center>
      </div>
    </body>
  </html>
</xsl:template>

</xsl:stylesheet>
