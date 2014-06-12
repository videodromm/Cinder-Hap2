#pragma once

#include "cinder/gl/GlslProg.h"

namespace cinder { namespace qtime {
	
	class Renderer {
	public:
		virtual ~Renderer() { }
	protected:
		Renderer();
		
		static Renderer& instance();
		static void render( const gl::TextureRef &frame, const Rectf &dstRect );
		
		ci::gl::GlslProgRef mRectShader;
		static std::unique_ptr<Renderer> mInstance;
		static std::once_flag mOnceFlag;
		
		friend void drawFrame (const gl::TextureRef &, const Rectf & );
	};
	
	//! Convienence render function using sampler2DRect & getCleanBounds() on gl::TextureRef.
	void drawFrame( const gl::TextureRef &frame, const Rectf &dstRect );
	
} }
