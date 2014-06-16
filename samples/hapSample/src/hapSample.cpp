#include "cinder/app/AppNative.h"
#include "cinder/app/RendererGl.h"
#include "cinder/Surface.h"
#include "cinder/gl/Texture.h"
#include "cinder/qtime/QuickTime.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#include "cinder/ImageIo.h"
//#include "cinder/gl/Query.h"

#include "Resources.h"

#include "MovieHap.h"

#include "RectRenderer.h"

using namespace ci;
using namespace ci::app;
using namespace std;

template <typename T> string tostr(const T& t, int p) { ostringstream os; os<<std::setprecision(p)<<std::fixed<<t; return os.str(); }

class QuickTimeSampleApp : public AppNative {
 public:
	void prepareSettings( Settings* settings );
	void setup();

	void keyDown( KeyEvent event );
	void fileDrop( FileDropEvent event );

	void update();
	void draw();

	void loadMovieFile( const fs::path &path );

	gl::TextureRef			mInfoTexture;
	gl::GlslProgRef			mHapQShader;
	qtime::MovieGlHapRef	mMovie;
	
//	gl::QueryTimeElapsedRef mQuery;
};

void QuickTimeSampleApp::prepareSettings( Settings* settings )
{
	settings->enableHighDensityDisplay();
}

void QuickTimeSampleApp::setup()
{
	mHapQShader = gl::GlslProg::create( app::loadResource(RES_HAP_VERT),  app::loadResource(RES_HAP_FRAG) );
	
//	mQuery = gl::QueryTimeElapsed::create();
	
	this->setFrameRate(60);
	this->setFpsSampleInterval(0.25);
//	fs::path moviePath = getOpenFilePath();
//	if( ! moviePath.empty() )
//		loadMovieFile( moviePath );
}

void QuickTimeSampleApp::keyDown( KeyEvent event )
{
	if( event.getChar() == 'f' ) {
		setFullScreen( ! isFullScreen() );
	}
	else if( event.getChar() == 'o' ) {
		fs::path moviePath = getOpenFilePath();
		if( ! moviePath.empty() )
			loadMovieFile( moviePath );
	}
	else if( event.getChar() == 'r' ) {
		mMovie.reset();
	}
}

void QuickTimeSampleApp::loadMovieFile( const fs::path &moviePath )
{
//	try {
		// load up the movie, set it to loop, and begin playing
		mMovie = qtime::MovieGlHap::create( moviePath );
		//mMovie.setAsRect();
		mMovie->setLoop();
		mMovie->play();
		
		// create a texture for showing some info about the movie
		TextLayout infoText;
		infoText.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
		infoText.setColor( Color::white() );
		infoText.addCenteredLine( moviePath.filename().string() );
		infoText.addLine( toString( mMovie->getWidth() ) + " x " + toString( mMovie->getHeight() ) + " pixels" );
		infoText.addLine( toString( mMovie->getDuration() ) + " seconds" );
		infoText.addLine( toString( mMovie->getNumFrames() ) + " frames" );
		infoText.addLine( toString( mMovie->getFramerate() ) + " fps" );
//		infoText.addLine( "Hap? " + std::string( mMovie->isHap() ? "Yes!" : "No." ) );
		infoText.setBorder( 4, 2 );
		mInfoTexture = gl::Texture::create( infoText.render( true ) );
//	}
//	catch( ... ) {
//		console() << "Unable to load the movie." << std::endl;
//		mInfoTexture.reset();
//	}

}

void QuickTimeSampleApp::fileDrop( FileDropEvent event )
{
	loadMovieFile( event.getFile( 0 ) );
}

void QuickTimeSampleApp::update()
{
//	if (mMovie)
//		mFrameTexture = mMovie->getTexture();
}

void QuickTimeSampleApp::draw()
{
	gl::clear( Color::black() );
	gl::enableAlphaBlending();
	gl::viewport( toPixels( getWindowSize() ) );
	
	// draw grid
	Vec2f sz = toPixels( getWindowSize() ) / Vec2f(8,6);
	gl::color( Color::gray(0.2));
	for (int x = 0 ; x < 8 ; x++ )
		for (int y = (x%2?0:1) ; y < 6 ; y+=2 )
			 gl::drawSolidRect( Rectf(0,0,sz.x,sz.y) + sz * Vec2f(x,y) );

//	// draw movie
//	if( mFrameTexture ) {
//		Rectf centeredRect = Rectf( mFrameTexture->getCleanBounds() ).getCenteredFit( getWindowBounds(), true );
//		gl::color( Color::gray(0.2));
//		gl::drawStrokedRect( centeredRect );
//		gl::color( Color::white() );
//		gl::draw( mFrameTexture, centeredRect  );
////		qtime::drawFrame( mFrameTexture, centeredRect );
//	}
	
	if (mMovie) {
//		mQuery->begin();
		mMovie->draw( mHapQShader );
//		mQuery->end();
//		app::console() << mQuery->getElapsedMilliseconds() << std::endl;
	}

	
	// draw info
	if( mInfoTexture ) {
		gl::draw( mInfoTexture, toPixels( Vec2f( 20, getWindowHeight() - 20 - mInfoTexture->getHeight() ) ) );
	}
	
	// draw fps
	TextLayout infoFps;
	infoFps.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
	infoFps.setColor( Color::white() );
	infoFps.addLine( "Movie Framerate: " + tostr( mMovie->getPlaybackFramerate(), 1 ) );
	infoFps.addLine( "App Framerate: " + tostr( this->getAverageFps(), 1 ) );
	infoFps.setBorder( 4, 2 );
	gl::draw( gl::Texture::create( infoFps.render( true ) ), Vec2f( 20, 20 ) );
}

CINDER_APP_NATIVE( QuickTimeSampleApp, RendererGl() );
