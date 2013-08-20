<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom"
  xmlns:th="http://dp-net.com/2013/th">

<xsl:include href="config.xsl"/>

<xsl:template match="atom:feed">
  <html>
    <head>
      <title><xsl:value-of select="atom:title"/></title>
      <xsl:call-template name="common-html-head-tags"/>
      <style type="text/css">
ul.links { list-style: none; margin: 0; padding: 0; display: inline }
ul.links li { display: inline }
ul.links li:after { content: "," } 
ul.links li:last-child:after { content: "" }
      </style>
    </head>
    <body>
      <xsl:call-template name="top-navigatoin-bar"/>
      <h1><xsl:value-of select="atom:title"/></h1>
      <xsl:if test="atom:entry[atom:category/@term='image' or atom:category/@term='video']">
        <p>
          <!-- h2>Images:</h2>  -->
          <xsl:apply-templates select="atom:entry[atom:category/@term='image' or atom:category/@term='video']"/>
        </p>
      </xsl:if>
      <xsl:if test="atom:entry[atom:category/@term='directory']">
        <div>
          <h2>Directories:</h2>
          <ul class="links"> 
            <xsl:apply-templates select="atom:entry[atom:category/@term='directory']"/>
          </ul>
        </div>
      </xsl:if>
    </body>
  </html>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='directory']">
  <li><a href="{atom:link/@href}"><xsl:value-of select="atom:title"/></a></li>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='image']">
  <a href="{atom:link/@href}">
    <xsl:apply-templates select="atom:link[@rel='alternate' and @type='image/jpg']" mode="image-thumbnail">
      <xsl:with-param name="size" select="'small'"/>
      <xsl:with-param name="class" select="'th'"/>
    </xsl:apply-templates>
  </a>
</xsl:template>

<xsl:template match="/atom:feed/atom:entry[atom:category/@term='video']">
  <a href="{atom:link/@href}"><img class="th" src="{atom:link[@rel='alternate' and @type='image/jpg']/@href}?type=image"/></a>
</xsl:template>

</xsl:stylesheet>