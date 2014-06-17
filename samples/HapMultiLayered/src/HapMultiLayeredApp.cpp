#include "cinder/app/AppNative.h"
#include "cinder/app/RendererGl.h"
#include "cinder/gl/gl.h"

#include "Resources.h"
#include "MovieHap.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class HapMultiLayeredApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();

	gl::GlslProgRef			mHapQShader;
	qtime::MovieGlHapRef	mMovieBg, mMovieFront;
};

void HapMultiLayeredApp::setup()
{
	mHapQShader = gl::GlslProg::create( app::loadResource( RES_HAP_VERT ), app::loadResource( RES_HAP_FRAG ) );

	setFrameRate( 60 );
	setFpsSampleInterval( 0.25 );


	mMovieBg = qtime::MovieGlHap::create( loadAsset( "SampleHapQ.mov" ) );
	mMovieFront = qtime::MovieGlHap::create( loadAsset( "SampleHapAlpha.mov" ) );

	mMovieBg->setLoop();
	mMovieBg->play();

	mMovieFront->setLoop();
	mMovieFront->play();

	gl::enableAlphaBlending();
}

void HapMultiLayeredApp::mouseDown( MouseEvent event )
{
}

void HapMultiLayeredApp::update()
{
}

void HapMultiLayeredApp::draw()
{
	gl::clear( Color::black() );
	gl::viewport( toPixels( getWindowSize() ) );

	if( mMovieBg ) {
		mMovieBg->draw( mHapQShader );
	}

	if( mMovieFront ) {
		mMovieFront->draw( mHapQShader );
	}
}

CINDER_APP_NATIVE( HapMultiLayeredApp, RendererGl )
