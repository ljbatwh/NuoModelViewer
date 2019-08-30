//
//  ModelRayTracingRenderer.m
//  ModelViewer
//
//  Created by middleware on 6/22/18.
//  Copyright © 2018 middleware. All rights reserved.
//

#import "ModelRayTracingRenderer.h"

#import "NuoInspectableMaster.h"
#import "NuoLightSource.h"

#import "NuoCommandBuffer.h"
#import "NuoBufferSwapChain.h"
#import "NuoRayBuffer.h"
#import "NuoRayAccelerateStructure.h"

#include "NuoRayTracingRandom.h"
#include "NuoComputeEncoder.h"
#include "NuoRenderPassAttachment.h"



static const uint32_t kRandomBufferSize = 256;
static const uint32_t kRayBounce = 4;





@implementation ModelRayTracingRenderer
{
    NuoComputePipeline* _primaryAndIncidentRaysPipeline;
    NuoComputePipeline* _rayShadePipeline;
    
    NuoBufferSwapChain* _rayTraceUniform;
    NuoBufferSwapChain* _randomBuffers;
    
    NuoRayBuffer* _incidentRaysBuffer;
    NuoRayBuffer* _shadowRaysBuffer;
    id<MTLBuffer> _shadowIntersectionBuffer;

    
    PNuoRayTracingRandom _rng;
}


- (instancetype)initWithCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    self = [super initWithCommandQueue:commandQueue
                       withPixelFormat:MTLPixelFormatRGBA32Float
                       withTargetCount:3 /* 2 for ambient/local-illumination, for normal and virtual surfaces,
                                          * 1 for direct lighting */ ];
    
    if (self)
    {
        _primaryAndIncidentRaysPipeline = [[NuoComputePipeline alloc] initWithDevice:commandQueue.device
                                                                        withFunction:@"primary_scafold"];
        _primaryAndIncidentRaysPipeline.name = @"Primary/Incident Ray Process";
        
        _rayShadePipeline = [[NuoComputePipeline alloc] initWithDevice:commandQueue.device
                                                          withFunction:@"incident_ray_process"];
        _rayShadePipeline.name = @"Incident Ray Shading";
        
        _rng = std::make_shared<NuoRayTracingRandom>(kRandomBufferSize, kRayBounce, 1);
        _rayTraceUniform = [[NuoBufferSwapChain alloc] initWithDevice:commandQueue.device
                                                       WithBufferSize:sizeof(NuoRayTracingUniforms)
                                                          withOptions:MTLResourceStorageModeManaged
                                                        withChainSize:kInFlightBufferCount];
        _randomBuffers = [[NuoBufferSwapChain alloc] initWithDevice:commandQueue.device
                                                     WithBufferSize:_rng->BytesSize()
                                                        withOptions:MTLResourceStorageModeManaged
                                                      withChainSize:kInFlightBufferCount];
    }
    
    return self;
}


- (void)setDrawableSize:(CGSize)drawableSize
{
    [super setDrawableSize:drawableSize];
    
    _incidentRaysBuffer = [[NuoRayBuffer alloc] initWithCommandQueue:self.commandQueue];
    _incidentRaysBuffer.dimension = drawableSize;
    
    _shadowRaysBuffer = [[NuoRayBuffer alloc] initWithCommandQueue:self.commandQueue];
    _shadowRaysBuffer.dimension = drawableSize;
    
    const size_t intersectionSize = drawableSize.width * drawableSize.height * kRayIntersectionStride;
    _shadowIntersectionBuffer = [self.commandQueue.device newBufferWithLength:intersectionSize
                                                                      options:MTLResourceStorageModePrivate];
}


- (void)updateUniforms:(id<NuoRenderInFlight>)inFlight
{
    NuoRayTracingUniforms uniforms;
    
    for (uint i = 0; i < 2; ++i)
    {
        NuoLightSource* lightSource = _lightSources[i];
        const NuoMatrixFloat44 matrix = NuoMatrixRotation(lightSource.lightingRotationX, lightSource.lightingRotationY);
        
        NuoRayTracingLightSource* lightSourceRayTracing = &(uniforms.lightSources[i]);
        
        lightSourceRayTracing->direction = matrix._m;
        lightSourceRayTracing->density = lightSource.lightingDensity;
        
        // the code used to pass lightSource.shadowSoften into the shader, which the shader had used as the diameter of
        // a disk which was distant from the lighted surface by the scene's dimension (i.e. maxDistance). in this
        // way, the calculation was duplicated for each pixel each ray, and would even duplicate in multiple places
        // among different shaders.
        //
        // now, the lightSource.shadowSoften is used as tangent of theta, with a scale factor that tries to
        // make the effect as close to the old behavior as possible. and the consine value is calculated from that
        // and passed to the shader. this approach need calculate the value once per render pass
        //
        float thetaTan = lightSource.shadowSoften / 2.0 * 0.25;
        lightSourceRayTracing->coneAngleCosine = (1 / sqrt(thetaTan * thetaTan + 1));
    }
    
    uniforms.bounds.span = _sceneBounds.MaxDimension();
    uniforms.bounds.center = NuoVectorFloat4(_sceneBounds._center._vector.x,
                                             _sceneBounds._center._vector.y,
                                             _sceneBounds._center._vector.z, 1.0)._vector;
    uniforms.globalIllum = _globalIllum;
    
    [_rayTraceUniform updateBufferWithInFlight:inFlight withContent:&uniforms];
    
    id<MTLBuffer> randomBuffer = [_randomBuffers bufferForInFlight:inFlight];
    _rng->SetBuffer(randomBuffer.contents);
    _rng->UpdateBuffer();
    [randomBuffer didModifyRange:NSMakeRange(0, _rng->BytesSize())];
}


- (void)runRayTraceShade:(NuoCommandBuffer*)commandBuffer
{
    // the shadow maps in the screen space are integrated by the sub renderers.
    // the master ray tracing renderer integrates the overlay result, e.g. self-illumination
    
    [self updateUniforms:commandBuffer];
    [self primaryRayEmit:commandBuffer];
    
    id<MTLBuffer> rayTraceUniform = [_rayTraceUniform bufferForInFlight:commandBuffer];
    id<MTLBuffer> randomBuffer = [_randomBuffers bufferForInFlight:commandBuffer];
    
    [self updatePrimaryRayMask:kNuoRayIndex_OnTranslucent withCommandBuffer:commandBuffer];
    
    if ([self primaryRayIntersect:commandBuffer])
    {
        // generate rays for the two light sources, from translucent objects
        //
        [self runRayTraceCompute:_primaryAndIncidentRaysPipeline withCommandBuffer:commandBuffer
                   withParameter:@[rayTraceUniform, randomBuffer,
                                   _shadowRaysBuffer.buffer,
                                   _shadowIntersectionBuffer,
                                   _incidentRaysBuffer.buffer]
                  withExitantRay:nil
                withIntersection:self.intersectionBuffer];
        
        for (uint i = 0; i < kRayBounce; ++i)
        {
            [self rayIntersect:commandBuffer withRays:_shadowRaysBuffer withIntersection:_shadowIntersectionBuffer];
            [self rayIntersect:commandBuffer withRays:_incidentRaysBuffer withIntersection:self.intersectionBuffer];
            
            [self runRayTraceCompute:_rayShadePipeline withCommandBuffer:commandBuffer
                       withParameter:@[rayTraceUniform, randomBuffer,
                                       _shadowRaysBuffer.buffer,
                                       _shadowIntersectionBuffer]
                      withExitantRay:_incidentRaysBuffer.buffer
                    withIntersection:self.intersectionBuffer];
        }
    }
        
    NuoInspectableMaster* inspect = [NuoInspectableMaster sharedMaster];
    [inspect updateTexture:self.targetTextures[2] forName:kInspectable_RayTracing];
}



@end
