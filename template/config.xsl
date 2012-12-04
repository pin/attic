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
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

<xsl:template name="top-navigatoin-bar">
  <div class="nav-bar bg-color-blueDark">
    <div class="nav-bar-inner">
      <!-- <span class="pull-menu" style="font-size: 17pt; float: left; margin-left: 0.3em; margin-top: 1px;"></span>  -->
      <a href="#" class="brand"><span class="element brand"></span></a>
      <script type="text/javascript"><![CDATA[
YUI().use('node', function (Y) {
  var t = document.URL.split('/');
  Y.one('a.brand').setAttribute('href', t[0] + '//' + t[2]);
  var h = location.hostname.split('.');
  if (h.length > 2) {
    Y.one('span.brand').append(h[0]);
  }
  else {
    Y.one('span.brand').append(location.hostname);
  }
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
  <a href="{@href}"><span class="element {$icon} icon-large" style="float: right; margin-top: 11px; margin-bottom: 0"/></a>
</xsl:template>

<xsl:template match="atom:link[@rel='up']" mode="navigation-link">
  <xsl:if test="ae:inline/atom:feed/atom:title">
    <xsl:apply-templates select="ae:inline/atom:feed/atom:link[@rel='up']" mode="navigation-link"/>
    <li><a href="{@href}"><xsl:value-of select="ae:inline/atom:feed/atom:title"/></a></li>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
