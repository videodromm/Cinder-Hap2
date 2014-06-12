

#include "RectRenderer.h"

#include "cinder/app/App.h"
#include "cinder/gl/Context.h"
#include "cinder/gl/Vbo.h"
#include "cinder/gl/Vao.h"
#include "cinder/qtime/QuickTime.h"

using namespace ci;
using namespace ci::qtime;

#if defined( CINDER_COCOA_TOUCH )
const char * vertShaderGlsl =
"uniform mat4	ciModelViewProjection;\n"
"attribute vec4		ciPosition;\n"
"attribute vec2		ciTexCoord0;\n"
"varying vec2		vTexCoord0;\n"
"void main( void ) {\n"
"	vTexCoord0 =	ciTexCoord0;\n"
"	gl_Position =	ciModelViewProjection * ciPosition;\n"
"}\n";
#elif defined( CINDER_MAC )
const char * vertShaderGlsl =
"#version 150\n"
"uniform mat4	ciModelViewProjection;\n"
"in vec4		ciPosition;\n"
"in vec2		ciTexCoord0;\n"
"out vec2		vTexCoord0;\n"
"void main( void ) {\n"
"	vTexCoord0 =	ciTexCoord0;\n"
"	gl_Position =	ciModelViewProjection * ciPosition;\n"
"}\n";
#endif

#if defined( CINDER_COCOA_TOUCH )
const char * fragShaderGlsl =
"uniform mediump sampler2D	uTex0;\n"
"uniform mediump vec2		uTexSize;\n"
"varying mediump vec2		vTexCoord0;\n"
"void main( void )\n"
"{\n"
"	gl_FragColor = texture2D(uTex0, vTexCoord0.st/uTexSize);\n"
"}\n";
#elif defined( CINDER_MAC )
const char * fragShaderGlsl =
"#version 150\n"
"uniform sampler2DRect	uTex0;\n"
"in vec2				vTexCoord0;\n"
"out vec4				oColor;\n"
"void main( void )\n"
"{\n"
"	oColor = texture(uTex0, vTexCoord0.st);\n"
"}\n";
#endif

std::unique_ptr<Renderer> Renderer::mInstance = nullptr;
std::once_flag Renderer::mOnceFlag;

Renderer& Renderer::instance()
{
	std::call_once(mOnceFlag,
				   [] {
					   mInstance.reset( new Renderer );
				   });
	return *mInstance.get();
}

Renderer::Renderer()
{
	
	try {
		mRectShader = gl::GlslProg::create( gl::GlslProg::Format().vertex( vertShaderGlsl ).fragment( fragShaderGlsl ) );
	}
	catch( gl::GlslProgCompileExc &exc ) {
		app::console() << "Shader compile error: " << std::endl;
		app::console() << exc.what();
	}
}

void Renderer::render( const gl::TextureRef &frame, const Rectf &dstRect )
{
	auto shader = instance().mRectShader;
	auto ctx = gl::context();
	gl::ScopedGlslProg ScopedGlslProg( shader );
	gl::ScopedTextureBind texBindScope( frame );
	
	shader->uniform( "uTex0", 0 );
	
	
	
	GLfloat data[8+8]; // both verts and texCoords
	GLfloat *verts = data, *texCoords = data + 8;
	
	Rectf texRect = frame->getCleanBounds();
	
#if defined( CINDER_COCOA_TOUCH )
	shader->uniform( "uTexSize",  texRect.getSize() );
#endif
	
	verts[0*2+0] = dstRect.getX2(); texCoords[0*2+0] = texRect.x2;
	verts[0*2+1] = dstRect.getY1(); texCoords[0*2+1] = texRect.y1;
	verts[1*2+0] = dstRect.getX1(); texCoords[1*2+0] = texRect.x1;
	verts[1*2+1] = dstRect.getY1(); texCoords[1*2+1] = texRect.y1;
	verts[2*2+0] = dstRect.getX2(); texCoords[2*2+0] = texRect.x2;
	verts[2*2+1] = dstRect.getY2(); texCoords[2*2+1] = texRect.y2;
	verts[3*2+0] = dstRect.getX1(); texCoords[3*2+0] = texRect.x1;
	verts[3*2+1] = dstRect.getY2(); texCoords[3*2+1] = texRect.y2;
	
	gl::VboRef defaultVbo = ctx->getDefaultArrayVbo( sizeof(float)*16 );
	gl::ScopedBuffer vboScp( defaultVbo );
	ctx->pushVao();
	ctx->getDefaultVao()->replacementBindBegin();
	defaultVbo->bufferSubData( 0, sizeof(float)*16, data );
	int posLoc = shader->getAttribSemanticLocation( geom::Attrib::POSITION );
	if( posLoc >= 0 ) {
		gl::enableVertexAttribArray( posLoc );
		gl::vertexAttribPointer( posLoc, 2, GL_FLOAT, GL_FALSE, 0, (void*)0 );
	}
	int texLoc = shader->getAttribSemanticLocation( geom::Attrib::TEX_COORD_0 );
	if( texLoc >= 0 ) {
		gl::enableVertexAttribArray( texLoc );
		gl::vertexAttribPointer( texLoc, 2, GL_FLOAT, GL_FALSE, 0, (void*)(sizeof(float)*8) );
	}
	ctx->getDefaultVao()->replacementBindEnd();
	
	ctx->setDefaultShaderVars();
	ctx->drawArrays( GL_TRIANGLE_STRIP, 0, 4 );
	ctx->popVao();
}


void qtime::drawFrame( const gl::TextureRef &frame, const Rectf &dstRect ) {
	assert( frame );
	Renderer::render( frame, dstRect );
}
