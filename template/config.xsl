<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:ae="http://purl.org/atom/ext/">

<xsl:template name="common-html-head-tags">
  <script src="http://yui.yahooapis.com/3.7.3/build/yui/yui-min.js" type="text/javascript"></script>
  <script type="text/javascript"><![CDATA[
document.cookie = 'resolution=' + Math.max(screen.width, screen.height) + '; path=/';
  ]]></script>
  <script type="text/javascript"><![CDATA[
window.addEventListener('load', function() {
  setTimeout(function() {
    window.scrollTo(0, 1);
  }, 0);
});
  ]]></script>
  <style>
@import url("/css/main.css");
@import url("/css/phone.css") (max-width: 800px);
div.navigation-bar, h1  {
  display: inline;
  font-size: 16pt;
}
div.navigation-bar:after {
  content: "&gt;"
}
.tile {
  padding: 10px 15px;
  background: #EEE;
  acolor: #FFF;
  text-decoration: none;
  font-size: 16pt;
}
.abottom-navigation-bar {
  position: fixed;
  bottom: 0px;
  right: 10px;
  font-size: 16pt;
}
a.previous, a.next {
  position: fixed;
  top: 50%;
}
a.previous {
  left: 1px;
}
a.next {
  right: 1px;
}
  </style>
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

<xsl:template name="top-navigatoin-bar">
  <div class="navigation-bar">
    <a href="#" class="brand tile"><span class="element brand" style="font-size: 16pt;"></span></a>
    <script type="text/javascript"><![CDATA[
YUI().use('node', function (Y) {
  var t = document.URL.split('/');
  Y.one('a.brand').setAttribute('href', t[0] + '//' + t[2]);
  var h = location.hostname.split('.');
  if (h.length > 2) {
    //Y.one('span.brand').append(h[0]);
  }
  else {
    //Y.one('span.brand').append(location.hostname);
  }
  Y.one('span.brand').append('popov.org');
});
    ]]></script>
    <xsl:apply-templates select="atom:link[@rel='up']" mode="navigation-link"/>
  </div>
  <xsl:apply-templates select="atom:link[@rel='previous']" mode="navigation-link">
    <xsl:with-param name="label" select="'&lt;'"/>
  </xsl:apply-templates>
<!--
  <xsl:apply-templates select="atom:link[@rel='index']" mode="navigation-link">
    <xsl:with-param name="label" select="'icon-grid-view'"/>
  </xsl:apply-templates>
-->
  <xsl:apply-templates select="atom:link[@rel='next']" mode="navigation-link">
    <xsl:with-param name="label" select="'&gt;'"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="atom:link" mode="navigation-link">
  <xsl:param name="label"/>
  <a href="{@href}" class="tile {@rel}" style="font-size: 20pt;"><xsl:value-of select="$label"/><!-- <xsl:value-of select="@rel"/>  --></a>
</xsl:template>
 
<xsl:template match="atom:link[@rel='up']" mode="navigation-link">
  <xsl:if test="ae:inline/atom:feed/atom:title">
    <xsl:apply-templates select="ae:inline/atom:feed/atom:link[@rel='up']" mode="navigation-link"/>
    &gt; <a href="{@href}" class="tile"><xsl:value-of select="ae:inline/atom:feed/atom:title"/></a>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
