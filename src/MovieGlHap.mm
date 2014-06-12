/*
 *  MovieGlHap.cpp
 *
 *  Created by Roger Sodre on 14/05/10.
 *  Copyright 2010 Studio Avante. All rights reserved.
 *
 */

#include "cinder/Cinder.h"
#include "cinder/app/App.h"
#include "cinder/Color.h"
#include "MovieGlHap.h"
#import "HapPixelBufferTexture.h"
extern "C" {
#include "HapSupport.h"
}

#include "Resources.h"

#define IS_HAP(hapTexture)		(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeRGB_DXT1)
#define IS_HAP_A(hapTexture)	(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeRGBA_DXT5)
#define IS_HAP_Q(hapTexture)	(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeYCoCg_DXT5)

namespace cinder { namespace qtime {

	// Playback Framerate
	uint32_t _FrameCount = 0;
	uint32_t _FpsLastSampleFrame = 0;
	double _FpsLastSampleTime = 0;
	float _AverageFps = 0;
	void updateMovieFPS( long time, void *ptr )
	{
		double now = app::getElapsedSeconds();
		if( now > _FpsLastSampleTime + app::App::get()->getFpsSampleInterval() ) {
			//calculate average Fps over sample interval
			uint32_t framesPassed = _FrameCount - _FpsLastSampleFrame;
			_AverageFps = (float)(framesPassed / (now - _FpsLastSampleTime));
			_FpsLastSampleTime = now;
			_FpsLastSampleFrame = _FrameCount;
		}
		_FrameCount++;
	}
	float MovieGlHap::getPlaybackFramerate()
	{
		return _AverageFps;
	}
	

	
	MovieGlHap::Obj::Obj()
	: MovieBase::Obj()
	, hapTexture(nullptr)
	, mHapGlsl( gl::GlslProg::create( app::loadResource(RES_HAP_VERT),  app::loadResource(RES_HAP_FRAG) ) )
	{
	}
	
	MovieGlHap::Obj::~Obj()
	{
		// see note on prepareForDestruction()
		prepareForDestruction();
		
		if (hapTexture)
		{
			NSLog(@"MovieGlHap :: HAP Destroy");
            [hapTexture release];
			hapTexture = NULL;
		}
	}
	
	
	MovieGlHap::MovieGlHap( const MovieLoader &loader )
	: MovieBase(), mObj( new Obj() )
	{
		MovieBase::initFromLoader( loader );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( const fs::path &path )
	: MovieBase(), mObj( new Obj() )
	{
		MovieBase::initFromPath( path );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( const void *data, size_t dataSize, const std::string &fileNameHint, const std::string &mimeTypeHint )
	: MovieBase(), mObj( new Obj() )
	{
		MovieBase::initFromMemory( data, dataSize, fileNameHint, mimeTypeHint );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( DataSourceRef dataSource, const std::string mimeTypeHint )
	: MovieBase(), mObj( new Obj() )
	{
		MovieBase::initFromDataSource( dataSource, mimeTypeHint );
		allocateVisualContext();
	}

	void MovieGlHap::allocateVisualContext()
	{
		// Load HAP Movie
		if ( (bIsHap = HapQTQuickTimeMovieHasHapTrackPlayable(getObj()->mMovie)) )
		{
			// QT Visual Context attributes
			OSStatus err = noErr;
			QTVisualContextRef * visualContext = (QTVisualContextRef*)&getObj()->mVisualContext;
			CFDictionaryRef pixelBufferOptions = HapQTCreateCVPixelBufferOptionsDictionary();
			NSDictionary *visualContextOptions = [NSDictionary dictionaryWithObject:(NSDictionary *)pixelBufferOptions
																			 forKey:(NSString *)kQTVisualContextPixelBufferAttributesKey];
			CFRelease(pixelBufferOptions);
			err = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)visualContextOptions, visualContext);
			if (err != noErr)
			{
				NSLog(@"HAP ERROR :: %ld, couldnt create visual context at %s", err, __func__);
				return;
			}
			// Set the new-frame callback. You could use another mechanism, such as a CVDisplayLink, instead
			//QTVisualContextSetImageAvailableCallback( *visualContext, VisualContextFrameCallback, (void*)this );
			// Set the movie's visual context
			err = SetMovieVisualContext( getObj()->mMovie, *visualContext );
			if (err != noErr)
			{
				NSLog(@"HAP ERROR :: %ld SetMovieVisualContext %s", err, __func__);
				return;
			}
			// The movie was attached to the context, we can start it now
			//this->play();
		}
		// Load non-HAP Movie
		else
		{			
			CGLContextObj cglContext = ::CGLGetCurrentContext();
			CGLPixelFormatObj cglPixelFormat = ::CGLGetPixelFormat( cglContext );
			
			// Creates a new OpenGL texture context for a specified OpenGL context and pixel format
			::QTOpenGLTextureContextCreate( kCFAllocatorDefault, cglContext, cglPixelFormat, NULL, (QTVisualContextRef*)&getObj()->mVisualContext );
			::SetMovieVisualContext( getObj()->mMovie, (QTVisualContextRef)getObj()->mVisualContext );
		}
		
		// Get codec name
		for (long i = 1; i <= GetMovieTrackCount(getObj()->mMovie); i++) {
            Track track = GetMovieIndTrack(getObj()->mMovie, i);
            Media media = GetTrackMedia(track);
            OSType mediaType;
            GetMediaHandlerDescription(media, &mediaType, NULL, NULL);
            if (mediaType == VideoMediaType)
            {
                // Get the codec-type of this track
                ImageDescriptionHandle imageDescription = (ImageDescriptionHandle)NewHandle(0); // GetMediaSampleDescription will resize it
                GetMediaSampleDescription(media, 1, (SampleDescriptionHandle)imageDescription);
                OSType codecType = (*imageDescription)->cType;
                DisposeHandle((Handle)imageDescription);
                
                switch (codecType) {
                    case 'Hap1':
						mCodecName = "Hap";
                        break;
                    case 'Hap5':
						mCodecName = "HapA";
                        break;
                    case 'HapY':
						mCodecName = "HapQ";
                        break;
                    default:
						char name[5] = {
							static_cast<char>((codecType>>24)&0xFF),
							static_cast<char>((codecType>>16)&0xFF),
							static_cast<char>((codecType>>8)&0xFF),
							static_cast<char>((codecType>>0)&0xFF),
							'\0' };
						mCodecName = std::string(name);
						//NSLog(@"codec [%s]",mCodecName.c_str());
                        break;
                }
            }
        }


		// Set framerate callback
//		this->setNewFrameCallback( updateMovieFPS, (void*)this );
	}
	
#if defined( CINDER_MAC )
	static void CVOpenGLTextureDealloc( gl::Texture *texture, void *refcon )
	{
		CVOpenGLTextureRelease( (CVImageBufferRef)(refcon) );
		delete texture;
	}
	
#endif // defined( CINDER_MAC )
	
	void MovieGlHap::Obj::releaseFrame()
	{
		mTexture.reset();
	}
	
	void MovieGlHap::Obj::newFrame( CVImageBufferRef cvImage )
	{
		// Load HAP frame
		CFTypeID imageType = CFGetTypeID(cvImage);
		if (imageType == CVPixelBufferGetTypeID())
		{
			// We re-use a texture for uploading the DXT pixel-buffer, create it if it doesn't already exist
			if (hapTexture == nil)
			{
				CGLContextObj cglContext = app::App::get()->getRenderer()->getCglContext();
				hapTexture = [[HapPixelBufferTexture alloc] initWithContext:cglContext];
				NSLog(@"MovieGlHap :: HAP Init");
			}
			
			// Update HAP texture
			hapTexture.buffer = cvImage;
			// Make gl::Texture
			GLenum target = GL_TEXTURE_2D;
			GLuint name = hapTexture.textureName;
			mTexture = gl::Texture::create( target, name, hapTexture.textureWidth, hapTexture.textureHeight, true );
//			app::console() << mWidth <<  " " << hapTexture.textureWidth <<  " " << mHeight <<  " " << hapTexture.textureHeight << std::endl;
			mTexture->setCleanTexCoords( mWidth/(float)hapTexture.textureWidth, mHeight/(float)hapTexture.textureHeight );
			mTexture->setFlipped( false );
			
			// Release CVimage (hapTexture has copied it)
			CVBufferRelease(cvImage);
		}
		// Load non-HAP frame
		else //if (imageType == CVOpenGLTextureGetTypeID())
		{
			CVOpenGLTextureRef imgRef = reinterpret_cast<CVOpenGLTextureRef>( cvImage );
			GLenum target = CVOpenGLTextureGetTarget( imgRef );
			GLuint name = CVOpenGLTextureGetName( imgRef );
			bool flipped = ! CVOpenGLTextureIsFlipped( imgRef );
			mTexture = gl::TextureRef( new gl::Texture( target, name, mWidth, mHeight, true ), std::bind( CVOpenGLTextureDealloc, std::placeholders::_1, imgRef ) );
			Vec2f t0, lowerRight, t2, upperLeft;
			::CVOpenGLTextureGetCleanTexCoords( imgRef, &t0.x, &lowerRight.x, &t2.x, &upperLeft.x );
			mTexture->setCleanTexCoords( std::max( upperLeft.x, lowerRight.x ), std::max( upperLeft.y, lowerRight.y ) );
			mTexture->setFlipped( flipped );
		}
	}
	
	void MovieGlHap::draw()
	{
		updateFrame();
		
		mObj->lock();
		if( mObj->mTexture ) {
			Rectf centeredRect = Rectf( app::toPixels( mObj->mTexture->getCleanBounds() ) ).getCenteredFit( app::toPixels( app::getWindowBounds() ), true );
			gl::color( Color::gray(0.2));
			gl::drawStrokedRect( centeredRect );
			gl::color( Color::white() );
			
			if( IS_HAP_Q(mObj->hapTexture) ) {
				gl::ScopedGlslProg shader( mObj->mHapGlsl );
				gl::ScopedTextureBind tex( mObj->mTexture );
				float cw = mObj->mTexture->getCleanWidth();
				float ch = mObj->mTexture->getCleanHeight();
				float w = mObj->mTexture->getWidth();
				float h = mObj->mTexture->getHeight();
				gl::drawSolidRect( centeredRect, Rectf(0, 0, cw/w, ch/h) );
			} else {
				gl::draw( mObj->mTexture, centeredRect );
			}
		}
		mObj->unlock();
	}
} } //namespace cinder::qtime
