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
#include "cinder/gl/Context.h"

#include "MovieGlHap.h"
//#import "HapPixelBufferTexture.h"
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
	, mDefaultShader( gl::getStockShader( gl::ShaderDef().texture() ) )
	{
	}
	
	MovieGlHap::Obj::~Obj()
	{
		// see note on prepareForDestruction()
		prepareForDestruction();
		mTexture.reset();
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
		if( HapQTQuickTimeMovieHasHapTrackPlayable( getObj()->mMovie ) )
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
	
	
//	void MovieGlHap::deallocateVisualContext()
//	{
//		if(mVideoTextureRef) {
//			CFRelease(mVideoTextureRef);
//			mVideoTextureRef = NULL;
//		}
//		
//		if(mVideoTextureCacheRef) {
//			CVOpenGLTextureCacheFlush(mVideoTextureCacheRef, 0);
//			CFRelease(mVideoTextureCacheRef);
//			mVideoTextureCacheRef = NULL;
//		}
//	}
	
	void MovieGlHap::Obj::releaseFrame()
	{
//		mTexture.reset();
	}
	
	void MovieGlHap::Obj::newFrame( CVImageBufferRef cvImage )
	{
		// Load HAP frame
		CFTypeID imageType = CFGetTypeID(cvImage);
		if (imageType == CVPixelBufferGetTypeID())
		{
			CVBufferRetain(cvImage);
			
			CVPixelBufferUnlockBaseAddress(cvImage, kCVPixelBufferLock_ReadOnly);
			CVBufferRelease(cvImage);
			
			auto buffer = cvImage;
			
			CVPixelBufferLockBaseAddress(cvImage, kCVPixelBufferLock_ReadOnly);
			
			GLuint width = CVPixelBufferGetWidth( cvImage );
			GLuint height = CVPixelBufferGetHeight( cvImage );
			
			assert(buffer != NULL);
			
			// Check the buffer padding
			
			size_t extraRight, extraBottom;
			
			CVPixelBufferGetExtendedPixels(buffer, NULL, &extraRight, NULL, &extraBottom);
			GLuint roundedWidth = width + extraRight;
			GLuint roundedHeight = height + extraBottom;
			
			// Valid DXT will be a multiple of 4 wide and high
			
			assert( !(roundedWidth % 4 != 0 || roundedHeight % 4 != 0) );
			
			OSType newPixelFormat = CVPixelBufferGetPixelFormatType(buffer);
			
			GLenum internalFormat;
			unsigned int bitsPerPixel;
			
			switch (newPixelFormat) {
				case kHapPixelFormatTypeRGB_DXT1:
					internalFormat = GL_COMPRESSED_RGB_S3TC_DXT1_EXT;
					bitsPerPixel = 4;
					break;
				case kHapPixelFormatTypeRGBA_DXT5:
				case kHapPixelFormatTypeYCoCg_DXT5:
					internalFormat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
					bitsPerPixel = 8;
					break;
				default:
					// we don't support non-DXT pixel buffers
					assert( false );
					return;
					break;
			}
			
			// Ignore the value for CVPixelBufferGetBytesPerRow()
			
			size_t bytesPerRow = (roundedWidth * bitsPerPixel) / 8;
			GLsizei newDataLength = bytesPerRow * roundedHeight; // usually not the full length of the buffer
			
			size_t actualBufferSize = CVPixelBufferGetDataSize( buffer );
			
			// Check the buffer is as large as we expect it to be
			
			if (newDataLength > actualBufferSize)
			{
				assert( false );
				return;
			}
			
            
			GLvoid *baseAddress = CVPixelBufferGetBaseAddress( buffer );
						
			if ( !mTexture ) {
				// On NVIDIA hardware there is a massive slowdown if DXT textures aren't POT-dimensioned, so we use POT-dimensioned backing
				GLuint backingWidth = 1;
				while (backingWidth < roundedWidth) backingWidth <<= 1;
				
				GLuint backingHeight = 1;
				while (backingHeight < roundedHeight) backingHeight <<= 1;
				
				// We allocate the texture with no pixel data, then use CompressedTexSubImage to update the content region
				gl::Texture::Format format;
				format.wrap(GL_CLAMP_TO_EDGE).magFilter(GL_LINEAR).minFilter(GL_LINEAR).internalFormat(internalFormat).pixelDataType(GL_UNSIGNED_INT_8_8_8_8_REV).pixelDataFormat(GL_BGRA);
				mTexture = gl::Texture::create(backingWidth, backingHeight, format );
				mTexture->setCleanTexCoords( width/(float)backingWidth, height/(float)backingHeight );
				mTexture->setFlipped( false );
				
				app::console() << "created texture." << std::endl;
				
				{
					gl::ScopedTextureBind bind( mTexture->getTarget(), mTexture->getId() );
					glTexParameteri( mTexture->getTarget(), GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_SHARED_APPLE );
				}
			}
			
			{
				gl::ScopedTextureBind bind( mTexture );
				glTextureRangeAPPLE(mTexture->getTarget(), newDataLength, baseAddress);
				glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
				
				glCompressedTexSubImage2D(mTexture->getTarget(),
										  0,
										  0,
										  0,
										  roundedWidth,
										  roundedHeight,
										  mTexture->getInternalFormat(),
										  newDataLength,
										  baseAddress);
				
			}

			// Release CVimage (hapTexture has copied it)
			CVBufferRelease(cvImage);
		}
	}
	
	void MovieGlHap::draw( const gl::GlslProgRef& hapQGlsl )
	{
		updateFrame();
		
		mObj->lock();
		if( mObj->mTexture ) {
			Rectf centeredRect = Rectf( app::toPixels( mObj->mTexture->getCleanBounds() ) ).getCenteredFit( app::toPixels( app::getWindowBounds() ), true );
			gl::color( Color::gray(0.2));
			gl::drawStrokedRect( centeredRect );
			gl::color( Color::white() );
			
			auto drawRect = [&]() {
				gl::ScopedTextureBind tex( mObj->mTexture );
				float cw = mObj->mTexture->getCleanWidth();
				float ch = mObj->mTexture->getCleanHeight();
				float w = mObj->mTexture->getWidth();
				float h = mObj->mTexture->getHeight();
				gl::drawSolidRect( centeredRect, Rectf(0, 0, cw/w, ch/h) );
			};
			
			if( hapQGlsl && mCodecName == "HapQ" ) {
				gl::ScopedGlslProg bind( hapQGlsl );
				drawRect();
			} else {
				gl::ScopedGlslProg bind( mObj->mDefaultShader );
				drawRect();
			}
		}
		mObj->unlock();
	}
} } //namespace cinder::qtime
