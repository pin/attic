<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:template name="common-html-head-tags">
  <!-- script>
    //alert('aaa');
  </script -->
  <!-- script src="http://yui.yahooapis.com/3.7.3/build/yui/yui-min.js"></script -->
  <style>
body {
        font-family: serif;
        font-size: 1em;
}
h1, h2, h3 {
        font-weight: lighter;
}
  </style>
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}"/>
</xsl:template>

</xsl:stylesheet>
