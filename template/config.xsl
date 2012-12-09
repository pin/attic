<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:ae="http://purl.org/atom/ext/">

<xsl:template name="common-html-head-tags">
  <script src="http://yui.yahooapis.com/3.7.3/build/yui/yui-min.js" type="text/javascript"></script>
  <script type="text/javascript"><![CDATA[
  //document.cookie = 'resolution=' + Math.max(screen.width, screen.height) + '; path=/';
  document.cookie = 'resolution=' + document.body.clientWidth + '; path=/';
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
@import url("/css/phone.css") (max-width: 600px);
a.previous, a.next {
  position: fixed;
  display: none;
  top: 50%;
}
a.previous {
  left: 1px;
}
a.next {
  right: 1px;
}
  </style>
  <script type="text/javascript"><![CDATA[
(function(doc) {
  var addEvent = 'addEventListener',
      type = 'gesturestart',
      qsa = 'querySelectorAll',
      scales = [1, 1],
      meta = qsa in doc ? doc[qsa]('meta[name=viewport]') : [];
  function fix() {
    meta.content = 'width=device-width,minimum-scale=' + scales[0] + ',maximum-scale=' + scales[1];
    doc.removeEventListener(type, fix, true);
  }
  if ((meta = meta[meta.length - 1]) && addEvent in doc) {
    fix();
    scales = [.25, 1.6];
    doc[addEvent](type, fix, true);
  }
}(document));
  ]]></script>
  <script type="text/javascript"><![CDATA[
var stdImageWidth = [300, 450, 600, 800, 1000, 1200];
YUI().use('node', function (Y) {
  window.addEventListener("orientationchange", function() {
    document.cookie = 'resolution=' + document.body.clientWidth + '; path=/';
    var width = document.body.clientWidth;
    var w = 300;
    stdImageWidth.forEach(function(stdWidth) {
      if (width > stdWidth && stdWidth > w) {
        w = stdWidth;
      }
    });
    var src = Y.one('img.main').getAttribute('src');
    src = src.replace(/size\=([a-z]+)/, 'px=' + w);
    src = src.replace(/px\=([0-9]+)/, 'px=' + w);
    Y.one('img.main').setAttribute('src', src);
  }, false);
});
  ]]></script>
  <!-- <meta name="viewport" content="width=device-width"/>  -->
  <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0"/>
</xsl:template>

<xsl:template match="atom:link" mode="head">
  <link rel="{@rel}" href="{@href}" class="navigation"/>
</xsl:template>

<xsl:template name="top-navigatoin-bar">
  <div class="navigation-bar">
    <a href="#" class="brand"><span class="brand"></span></a>
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
  //Y.one('span.brand').append('popov.org');
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
  <a href="{@href}" class="{@rel}" style="font-size: 20pt;"><xsl:value-of select="$label"/><!-- <xsl:value-of select="@rel"/>  --></a>
</xsl:template>
 
<xsl:template match="atom:link[@rel='up']" mode="navigation-link">
  <xsl:if test="ae:inline/atom:feed/atom:title">
    <xsl:apply-templates select="ae:inline/atom:feed/atom:link[@rel='up']" mode="navigation-link"/>
    / <a href="{@href}"><xsl:value-of select="ae:inline/atom:feed/atom:title"/></a>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
