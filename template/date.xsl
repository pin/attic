<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dp="http://dp-net.com/2012/xslt/date">  
 <xsl:output method="text"/>

 <dp:months>
  <m>Jan</m><m>Feb</m><m>Mar</m><m>Apr</m><m>May</m><m>Jun</m>
  <m>Jul</m><m>Aug</m><m>Sep</m><m>Oct</m><m>Nov</m><m>Dec</m>
 </dp:months>

 <dp:months1>
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
 </dp:months1>

 <xsl:variable name="vMonthNames" select=
 "document('')/*/dp:months1/*"/>

  <xsl:template match="text()" name="date">
    <xsl:variable name="year" select="substring-before(., '-')"/>

     <xsl:variable name="vnumMonth" select=
     "substring-before(substring-after(., '-'), '-')"/>

     <xsl:variable name="vDay" select=
     "substring-after(substring-after(., '-'), '-')"/>

<!-- 
     <xsl:value-of select=
      "concat($vMonthNames[0+$vnumMonth], ' ',
              $vDay, ', ',
              $vYear
              )"/>

 -->
 
     <xsl:value-of select="concat(number($vDay), '&#160;', $vMonthNames[0+$vnumMonth], '&#160;', $year)"/>
              
 </xsl:template>
</xsl:stylesheet>
