//
//  NuoModelArrow.cpp
//  ModelViewer
//
//  Created by middleware on 8/28/16.
//  Copyright © 2016 middleware. All rights reserved.
//

#include "NuoModelArrow.h"
#include <math.h>



static const size_t kNumOfFins = 36;




NuoModelArrow::NuoModelArrow(float bodyLength, float bodyRadius, float headLength, float headRadius)
: _bodyLength(bodyLength),
  _bodyRadius(bodyRadius),
  _headLength(headLength),
  _headRadius(headRadius)
{
}


void NuoModelArrow::CreateBuffer()
{
    CreateEndSurface();
    CreateBodySurface();
}


vector_float4 NuoModelArrow::GetBodyVertex(size_t index, size_t type)
{
    float arc = ((float)index / (float)kNumOfFins) * 2 * 3.1416;
    float x = cos(arc) * _bodyRadius;
    float y = sin(arc) * _bodyRadius;
    float z = type * _bodyLength;
    
    return vector_float4 {x, y, z, 1.0};
}


vector_float4 NuoModelArrow::GetBodyNormal(size_t index)
{
    float arc = ((float)index / (float)kNumOfFins) * 2 * 3.1416;
    float x = cos(arc);
    float y = sin(arc);
    
    return vector_float4 { x, y, 0, 0 };
}


vector_float4 NuoModelArrow::GetEndVertex(size_t type)
{
    float length = _bodyLength + _headLength;
    return vector_float4 { 0, 0, length * type, 1.0 };
}


vector_float4 NuoModelArrow::GetHeadVertex(size_t index)
{
    float arc = ((float)index / (float)kNumOfFins) * 2 * 3.1416;
    float x = cos(arc) * _headRadius;
    float y = sin(arc) * _headRadius;
    float z = _bodyLength;
    
    return vector_float4 {x, y, z, 1.0};
}


void NuoModelArrow::CreateEndSurface()
{
    vector_float4 endCenter = { 0, 0, 0, 1.0 };
    std::vector<float> bufferPosition(9), bufferNormal(3);
    
    bufferNormal[0] = 0;
    bufferNormal[1] = 0;
    bufferNormal[2] = -1.0;
    
    for (size_t index = 0; index < kNumOfFins; ++ index)
    {
        vector_float4 edgeVertex1 = GetBodyVertex(index, 0);
        vector_float4 edgeVertex2 = GetBodyVertex(index + 1, 0);
        
        bufferPosition[0] = endCenter.x;
        bufferPosition[1] = endCenter.y;
        bufferPosition[2] = endCenter.z;
        bufferPosition[3] = edgeVertex1.x;
        bufferPosition[4] = edgeVertex1.y;
        bufferPosition[5] = edgeVertex1.z;
        bufferPosition[6] = edgeVertex2.x;
        bufferPosition[7] = edgeVertex2.y;
        bufferPosition[8] = edgeVertex2.z;
        
        AddPosition(0, bufferPosition);
        AddNormal(0, bufferNormal);
        AddPosition(3, bufferPosition);
        AddNormal(0, bufferNormal);
        AddPosition(6, bufferPosition);
        AddNormal(0, bufferNormal);
    }
}


void NuoModelArrow::CreateBodySurface()
{
    std::vector<float> bufferPosition(18), bufferNormal;
    
    for (size_t index = 0; index < kNumOfFins; ++ index)
    {
        vector_float4 endVertex1 = GetBodyVertex(index, 0);
        vector_float4 endVertex2 = GetBodyVertex(index + 1, 0);
        vector_float4 headVertex1 = GetBodyVertex(index, 1);
        vector_float4 headVertex2 = GetBodyVertex(index + 1, 1);
        
        vector_float4 normal1 = GetBodyNormal(index);
        vector_float4 normal2 = GetBodyNormal(index + 1);
        
        // triangle 1
        bufferPosition[0] = headVertex1.x;
        bufferPosition[1] = headVertex1.y;
        bufferPosition[2] = headVertex1.z;
        bufferPosition[3] = endVertex1.x;
        bufferPosition[4] = endVertex1.y;
        bufferPosition[5] = endVertex1.z;
        bufferPosition[6] = headVertex2.x;
        bufferPosition[7] = headVertex2.y;
        bufferPosition[8] = headVertex2.z;
        
        bufferNormal[0] = normal1.x;
        bufferNormal[1] = normal1.y;
        bufferNormal[2] = normal1.z;
        bufferNormal[3] = normal1.x;
        bufferNormal[4] = normal1.y;
        bufferNormal[5] = normal1.z;
        bufferNormal[6] = normal2.x;
        bufferNormal[7] = normal2.y;
        bufferNormal[8] = normal2.z;
        
        // triangle 2
        bufferPosition[9] = headVertex2.x;
        bufferPosition[10] = headVertex2.y;
        bufferPosition[11] = headVertex2.z;
        bufferPosition[12] = endVertex1.x;
        bufferPosition[13] = endVertex1.y;
        bufferPosition[14] = endVertex1.z;
        bufferPosition[15] = endVertex2.x;
        bufferPosition[16] = endVertex2.y;
        bufferPosition[17] = endVertex2.z;
        
        bufferNormal[0] = normal2.x;
        bufferNormal[1] = normal2.y;
        bufferNormal[2] = normal2.z;
        bufferNormal[3] = normal1.x;
        bufferNormal[4] = normal1.y;
        bufferNormal[5] = normal1.z;
        bufferNormal[6] = normal2.x;
        bufferNormal[7] = normal2.y;
        bufferNormal[8] = normal2.z;
        
        AddPosition(0, bufferPosition);
        AddNormal(0, bufferNormal);
        AddPosition(3, bufferPosition);
        AddNormal(3, bufferNormal);
        AddPosition(6, bufferPosition);
        AddNormal(6, bufferNormal);
        
        AddPosition(9, bufferPosition);
        AddNormal(9, bufferNormal);
        AddPosition(12, bufferPosition);
        AddNormal(12, bufferNormal);
        AddPosition(15, bufferPosition);
        AddNormal(15, bufferNormal);
    }
}


