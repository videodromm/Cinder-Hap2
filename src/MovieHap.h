/*
 *  MovieGlHap.h
 *
 *  Created by Roger Sodre on 14/05/10.
 *  Copyright 2010 Studio Avante. All rights reserved.
 *
 */
#pragma once

#include "cinder/Cinder.h"
#include "cinder/gl/gl.h"
#include "cinder/qtime/Quicktime.h"
#include "cinder/gl/GlslProg.h"

namespace cinder { namespace qtime {
	
	typedef std::shared_ptr<class MovieGlHap> MovieGlHapRef;
	
	class MovieGlHap : public MovieBase {
	public:
		~MovieGlHap();
		MovieGlHap( const fs::path &path );
		MovieGlHap( const class MovieLoader &loader );
		MovieGlHap( const void *data, size_t dataSize, const std::string &fileNameHint, const std::string &mimeTypeHint = "" );
		MovieGlHap( DataSourceRef dataSource, const std::string mimeTypeHint = "" );
				
		void draw( const gl::GlslProgRef& hapQGlsl );
		
		std::string &	getCodecName()				{ return mCodecName; }		// The codec name of the loaded movie
		float			getPlaybackFramerate();									// The actual playback framerate
		
		
		static MovieGlHapRef create( const fs::path &path ) { return MovieGlHapRef( new MovieGlHap( path ) ); }
		static MovieGlHapRef create( const MovieLoaderRef &loader );
		static MovieGlHapRef create( const void *data, size_t dataSize, const std::string &fileNameHint, const std::string &mimeTypeHint = "" )
		{ return MovieGlHapRef( new MovieGlHap( data, dataSize, fileNameHint, mimeTypeHint ) ); }
		static MovieGlHapRef create( DataSourceRef dataSource, const std::string mimeTypeHint = "" )
		{ return MovieGlHapRef( new MovieGlHap( dataSource, mimeTypeHint ) ); }
	protected:
		
		void allocateVisualContext();

		std::string	mCodecName;

		struct Obj : public MovieBase::Obj {
			Obj();
			~Obj();
			
			virtual void		releaseFrame();
			virtual void		newFrame( CVImageBufferRef cvImage );
			
			gl::TextureRef		mTexture;
			gl::GlslProgRef		mDefaultShader;
		};
		
		std::unique_ptr<Obj>		mObj;
		virtual MovieBase::Obj*		getObj() const { return mObj.get(); }
	};

} } //namespace cinder::qtime
