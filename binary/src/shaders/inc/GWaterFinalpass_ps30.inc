// ALL SKIP STATEMENTS THAT AFFECT THIS SHADER!!!
// defined $HDRTYPE && defined $HDRENABLED && !$HDRTYPE && $HDRENABLED
// defined $PIXELFOGTYPE && defined $WRITEWATERFOGTODESTALPHA && ( $PIXELFOGTYPE != 1 ) && $WRITEWATERFOGTODESTALPHA
// defined $LIGHTING_PREVIEW && defined $HDRTYPE && $LIGHTING_PREVIEW && $HDRTYPE != 0
// defined $LIGHTING_PREVIEW && defined $FASTPATHENVMAPTINT && $LIGHTING_PREVIEW && $FASTPATHENVMAPTINT
// defined $LIGHTING_PREVIEW && defined $FASTPATHENVMAPCONTRAST && $LIGHTING_PREVIEW && $FASTPATHENVMAPCONTRAST
// defined $LIGHTING_PREVIEW && defined $FASTPATH && $LIGHTING_PREVIEW && $FASTPATH
// ($FLASHLIGHT || $FLASHLIGHTSHADOWS) && $LIGHTING_PREVIEW

#pragma once
#include "shaderlib/cshader.h"
class GWaterFinalpass_ps30_Static_Index
{
public:
	GWaterFinalpass_ps30_Static_Index( )
	{
	}

	int GetIndex() const
	{
		return 0;
	}
};

#define shaderStaticTest_GWaterFinalpass_ps30 1


class GWaterFinalpass_ps30_Dynamic_Index
{
	unsigned int m_nOPAQUE : 2;
#ifdef _DEBUG
	bool m_bOPAQUE : 1;
#endif	// _DEBUG
public:
	void SetOPAQUE( int i )
	{
		Assert( i >= 0 && i <= 1 );
		m_nOPAQUE = i;
#ifdef _DEBUG
		m_bOPAQUE = true;
#endif	// _DEBUG
	}

	GWaterFinalpass_ps30_Dynamic_Index( )
	{
		m_nOPAQUE = 0;
#ifdef _DEBUG
		m_bOPAQUE = false;
#endif	// _DEBUG
	}

	int GetIndex() const
	{
		Assert( m_bOPAQUE );
		return ( 1 * m_nOPAQUE ) + 0;
	}
};

#define shaderDynamicTest_GWaterFinalpass_ps30 psh_forgot_to_set_dynamic_OPAQUE

