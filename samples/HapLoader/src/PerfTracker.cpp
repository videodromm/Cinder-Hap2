//
//#include "PerfTracker.h"
//
//using namespace ci;
//
//#include "cinder/GeomIo.h"
//#include "cinder/gl/VboMesh.h"
//#include "cinder/gl/Vbo.h"
//#include "cinder/gl/Shader.h"
//#include "cinder/Log.h"
//#include "cinder/Rand.h"
//
//#include <iostream>
//#include <limits>
//#include <algorithm>
//
//const size_t PerfTracker::sMaxFrames = 200;
//
//PerfTracker::Signal::Signal( std::string name )
//: mMinMax( std::numeric_limits<float>::min(), std::numeric_limits<float>::max() )
//, mName( name )
//, mColor( CM_HSV, Rand::randFloat(), 0.5f, 1.0f )
//{
//	geom::BufferLayout shapeLayout;
//	shapeLayout.append( geom::Attrib::POSITION, 2, 0, 0 );
//	mPositionVbo = gl::Vbo::create( GL_ARRAY_BUFFER, std::vector<Vec2f>( sMaxFrames ), GL_DYNAMIC_DRAW );
//	
//	auto mesh = gl::VboMesh::create( sMaxFrames, GL_LINE_STRIP, { { shapeLayout, mPositionVbo } } );
//	mLine = gl::Batch::create( mesh, gl::getStockShader( gl::ShaderDef().color() ) );
//}
//
//
//// CPU SIGNAL ////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//
//PerfTracker::CpuSignal::CpuSignal( std::string name )
//: PerfTracker::Signal( name )
//{
//	mColor = Color(1,0,0);
//}
//
//void PerfTracker::CpuSignal::startFrame()
//{
//	mTimer.stop();
//	mFrameTimes.emplace_front( mTimer.getSeconds() );
//	if( mFrameTimes.size() > sMaxFrames ) {
//		mFrameTimes.pop_back();
//	}
//	mTimer.start();
//}
//
//// GPU SIGNAL ////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
//
//PerfTracker::GpuSignal::GpuSignal( std::string name )
//: PerfTracker::Signal( name )
//, mQuery( gl::QueryTimeElapsed::create() )
//{
//	mColor = Color(0,1,0);
//}
//
//void PerfTracker::GpuSignal::startFrame()
//{
//	mFrameTimes.emplace_front( mQuery->getElapsedSeconds() );
//	if( mFrameTimes.size() > sMaxFrames ) {
//		mFrameTimes.pop_back();
//	}
//	mQuery->begin();
//}
//
//void PerfTracker::GpuSignal::endFrame()
//{
//	mQuery->end();
//}
//
//// PERFORMANCE TRACKER ///////////////////////////////////////
////////////////////////////////////////////////////////////////
//
//PerfTracker::PerfTracker( const ci::Area& area )
//: mArea( area )
//{
//	mSignals.emplace_back( std::unique_ptr<Signal>( new CpuSignal( "CPU time" ) ) );
//	
//	mSignals.emplace_back( std::unique_ptr<Signal>( new GpuSignal( "GPU time" ) ) );
//}
//
//void PerfTracker::startFrame()
//{
//	for( auto& signal : mSignals ) {
//		signal->startFrame();
//	}
//}
//
//void PerfTracker::endFrame()
//{
//	for( auto& signal : mSignals ) {
//		signal->endFrame();
//	}
//}
//
//void PerfTracker::update()
//{
//	
//}
//
//void PerfTracker::draw()
//{
//	for( auto& signal : mSignals ) {
//		
//		// update our instance positions; map our instance data VBO, write new positions, unmap
//		Vec2f *positions = (Vec2f*)signal->mPositionVbo->map( GL_WRITE_ONLY );
//				
//		CI_ASSERT( signal->mFrameTimes.size() <= sMaxFrames );
//		
//		auto minmax = std::minmax_element( signal->mFrameTimes.begin(), signal->mFrameTimes.end() );
//		signal->mMinMax.first = *minmax.first;
//		signal->mMinMax.second = *minmax.second;
//		
//		for( size_t i =0; i<sMaxFrames; ++i ) {
//			
//			if( i >= signal->mFrameTimes.size() )
//				break;
//			
//			double frameTime = signal->mFrameTimes.at( i );
//			
////			if( frameTime > signal->mLimits.first )
////				signal->mLimits.first = frameTime;
////			
////			if( frameTime < signal->mLimits.second )
////				signal->mLimits.second = frameTime;
//			
//			double interval = signal->mMinMax.second - signal->mMinMax.first;
//			
//			*positions = Vec2f( mArea.getX1() + mArea.getWidth() * i/(float)sMaxFrames,
//							    (1.0 - (frameTime - signal->mMinMax.first)/(interval+0.0001)) * mArea.getHeight() );
//			
//			positions++;
//			
//		}
//		signal->mPositionVbo->unmap();
//		
//		gl::color( signal->mColor );
//		signal->mLine->draw();
//	}
//	
//	gl::color( Color::white() );
//	gl::drawStrokedRect( mArea );
//}
