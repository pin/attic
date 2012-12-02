<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:template name="common-html-head-tags">
  <link href="https://raw.github.com/olton/Metro-UI-CSS/master/css/modern.css" rel="stylesheet"/>
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
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

</xsl:stylesheet>
