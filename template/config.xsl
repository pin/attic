<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:ae="http://purl.org/atom/ext/">

<xsl:template name="common-html-head-tags">
  <link href="/css/modern.css" type="text/css" rel="stylesheet"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <link href="/css/modern-responsive.css" type="text/css" rel="stylesheet"/>
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
.page {
  margin-left: 0.2em;
  margin-right: 0.2em;
}
  </style>
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

<xsl:template name="top-navigatoin-bar">
  <div class="nav-bar bg-color-white">
    <div class="nav-bar-inner">
      <!-- <span class="pull-menu" style="font-size: 17pt; float: left; margin-left: 0.3em; margin-top: 1px;"></span>  -->
      <a href="#" class="brand"><span class="element brand" style="font-size: 16pt; margin-top: 5px;"></span></a>
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
      <xsl:apply-templates select="atom:link[@rel='next']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-arrow-right'"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="atom:link[@rel='index']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-grid-view'"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="atom:link[@rel='previous']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-arrow-left'"/>
      </xsl:apply-templates>
      <xsl:if test="atom:link[@rel='up']/ae:inline/atom:feed/atom:title">
        <span class="divider"/>
      </xsl:if>
      <ul class="menu">
        <xsl:apply-templates select="atom:link[@rel='up']" mode="navigation-link"/>
      </ul>
    </div>
  </div>
  <script src="/js/assets/jquery-1.8.2.min.js"></script>
  <script src="/js/modern/dropdown.js"></script>
</xsl:template>

<xsl:template match="atom:link" mode="navigation-link">
  <xsl:param name="icon"/>
  <a href="{@href}"><span class="element {$icon} icon-large" style="font-size: 12pt; color: lightGrey !important; float: right; margin-top: 11px; margin-bottom: 0; margin-right: 0.5em"/></a>
</xsl:template>

<xsl:template match="atom:link[@rel='up']" mode="navigation-link">
  <xsl:if test="ae:inline/atom:feed/atom:title">
    <xsl:apply-templates select="ae:inline/atom:feed/atom:link[@rel='up']" mode="navigation-link"/>
    <li><a href="{@href}" style="font-size: 12pt"><xsl:value-of select="ae:inline/atom:feed/atom:title"/></a></li>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
