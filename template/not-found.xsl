<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:include href="config.xsl"/>

<xsl:template match="atom:entry">
  <html>
    <head>
      <title>404</title>
      <xsl:call-template name="common-html-head-tags"/>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1>???</h1>
      <p style="margin-left: 2em; margin-top: 2em; font-size: larger">
        The requested URL was <strong>not found</strong>, try start from the <a href="/">home page</a> or use links above.
      </p>
      <p style="margin-top: 3em">
        <img src="/images/xkcd-404.gif"/>
      </p>
    </body>
  </html>
</xsl:template>

</xsl:stylesheet>