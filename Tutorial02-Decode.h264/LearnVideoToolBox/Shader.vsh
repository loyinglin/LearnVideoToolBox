//
//  ViewController.m
//  LearnOpenGLESWithGPUImage
//
//  Created by loyinglin on 16/5/10.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

attribute vec4 position;
attribute vec2 texCoord;

varying vec2 texCoordVarying;

void main()
{
    float preferredRotation = 3.14;
    mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
                               0.0,					    0.0, 1.0, 0.0,
                               0.0,					    0.0, 0.0, 1.0);
    gl_Position = rotationMatrix * position;
    texCoordVarying = texCoord;
}

