<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">

<xsl:template name="common-html-head-tags">
  <link href="https://raw.github.com/olton/Metro-UI-CSS/master/css/modern.css" type="text/css" rel="stylesheet"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <link href="https://raw.github.com/olton/Metro-UI-CSS/master/css/modern-responsive.css" type="text/css" rel="stylesheet"/>
  <script src="http://yui.yahooapis.com/3.7.3/build/yui/yui-min.js" type="text/javascript"></script>
  <script type="text/javascript"><![CDATA[
YUI().use('node', 'event', function (Y) {
  Y.on("domready", function (e) {
    Y.one('span.brand').append(location.hostname);
    Y.one('a.brand').setAttribute('href', location.origin);
  });  
});
  ]]></script>
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

<xsl:template name="top-navigatoin-bar">
  <div class="nav-bar bg-color-blueDark">
    <div class="nav-bar-inner">
      <span class="pull-menu" style="float: left; margin-left: 0.3em; margin-top: 1px;"></span>
      <a href="#" class="brand"><span class="element brand"></span></a>
      <xsl:apply-templates select="atom:link[@rel='next']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-arrow-right'"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="atom:link[@rel='index']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-grid-view'"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="atom:link[@rel='previous']" mode="navigation-link">
        <xsl:with-param name="icon" select="'icon-arrow-left'"/>
      </xsl:apply-templates>
      <span class="divider"/>
      <ul class="menu">
        <li data-role="dropdown">
          <a href="#">Item 3</a>
          <ul class="dropdown-menu">
            <li><a href="#">aaaaa</a></li>
            <li><a href="#">bbbbb</a></li>
          </ul>
        </li>
        <li>
          <a href="#">Item 4</a>
        </li>
      </ul>
    </div>
  </div>
  <script src="http://metroui.org.ua/js/assets/jquery-1.8.2.min.js"></script>
  <script src="http://metroui.org.ua/js/modern/dropdown.js"></script>
</xsl:template>

<xsl:template match="atom:link" mode="navigation-link">
  <xsl:param name="icon"/>
  <a href="{@href}"><span class="element {$icon}" style="float: right; margin-top: 4px"/></a>
  <!-- <a href="{@href}"><span class="element brand" style="float: right"><xsl:value-of select="@rel"/></span></a> -->
</xsl:template>

</xsl:stylesheet>
