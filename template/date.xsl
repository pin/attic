<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dp="http://dp-net.com/2012/XSL/Date">  
  <xsl:output method="text"/>

<dp:month-en>
  <m>Jan</m>
  <m>Feb</m>
  <m>Mar</m>
  <m>Apr</m>
  <m>May</m>
  <m>Jun</m>
  <m>Jul</m>
  <m>Aug</m>
  <m>Sep</m>
  <m>Oct</m>
  <m>Nov</m>
  <m>Dec</m>
</dp:month-en>

<dp:month-ru>
  <m>января</m>
  <m>февраля</m>
  <m>марта</m>
  <m>апреля</m>
  <m>мая</m>
  <m>июня</m>
  <m>июля</m>
  <m>августа</m>
  <m>сентября</m>
  <m>октября</m>
  <m>ноября</m>
  <m>декабря</m>
</dp:month-ru>

<xsl:variable name="monthNames" select="document('')/*/dp:month-ru/*"/>

<xsl:template match="text()" name="iso-date">
  <xsl:variable name="year" select="substring-before(., '-')"/>
  <xsl:variable name="month" select="substring-before(substring-after(., '-'), '-')"/>
  <xsl:variable name="day" select="substring-after(substring-after(., '-'), '-')"/>
  <xsl:value-of select="concat(number($day), '&#160;', $monthNames[0 + $month], '&#160;', $year)"/>
</xsl:template>

<xsl:template match="text()" name="exif-date">
  <xsl:variable name="year" select="substring-before(., ':')"/>
  <xsl:variable name="month" select="substring-before(substring-after(., ':'), ':')"/>
  <xsl:variable name="day" select="substring-before(substring-after(substring-after(., ':'), ':'), ' ')"/>
  <xsl:value-of select="concat(number($day), '&#160;', $monthNames[0 + $month], '&#160;', $year)"/>
</xsl:template>

</xsl:stylesheet>
