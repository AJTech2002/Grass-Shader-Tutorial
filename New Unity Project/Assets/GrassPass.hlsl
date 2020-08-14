struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 uv           : TEXCOORD0;
    float2 uvLM         : TEXCOORD1;
    float4 color : COLOR;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct Varyings
{
    
    float3 normalOS : NORMAL;
    float2 uv                       : TEXCOORD0;
    float2 uvLM                     : TEXCOORD1;
    float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
    half3  normalWS                 : TEXCOORD3;
    half3 tangentWS                 : TEXCOORD4;
    float4 positionOS : TEXCOORD5;
    
    float4 color : COLOR;
#if _NORMALMAP

    half3 bitangentWS               : TEXCOORD5;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
    float4 positionCS               : SV_POSITION;
};

float Height;
float4 _Vect;
float4 _Darker;
float _TranslucencyFactor;
float _ShadowAffectance;

float rand(float3 co)
{
    return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}


float Ang;
float Base;
float Speed;
float _LightAffectance;

float AlphaCutoff;



    float2 _WindFrequency;
    float _WindStrength;
    
    
//* The following has been kept to the bare minimum to transfer shadows and lighting *// 

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    
    output.color = input.color;
    // VertexPositionInputs contains position in multiple spaces (world, view, homogeneous clip space)
    // Our compiler will strip all unused references (say you don't use view space).
    // Therefore there is more flexibility at no additional cost with this struct.

    float3 posObj = input.positionOS.xyz;
    
    

    //posObj += TransformWorldToObject((0, Height, 0))*Height;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(posObj);

    // Similar to VertexPositionInputs, VertexNormalInputs will contain normal, tangent and bitangent
    // in world space. If not used it will be stripped.
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Computes fog factor per-vertex.
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    // TRANSFORM_TEX is the same as the old shader library.
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;

    output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS;
    output.tangentWS = vertexNormalInput.tangentWS;


    // Here comes the flexibility of the input structs.
    // In the variants that don't have normal map defined
    // tangentWS and bitangentWS will not be referenced and
    // GetVertexNormalInputs is only converting normal
    // from object to world space
#ifdef _NORMALMAP

    output.bitangentWS = vertexNormalInput.bitangentWS;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
    // shadow coord for the main light is computed in vertex.
    // If cascades are enabled, LWRP will resolve shadows in screen space
    // and this coord will be the uv coord of the screen space shadow texture.
    // Otherwise LWRP will resolve shadows in light space (no depth pre-pass and shadow collect pass)
    // In this case shadowCoord will be the position in light space.
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    // We just use the homogeneous clip position from the vertex input
    output.positionCS = vertexInput.positionCS;
    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    return output;
}



float3x3 RotY(float ang)
{
    return float3x3

        (
            cos(ang), 0, sin(ang),
            0, 1, 0,
            -sin(ang), 0, cos(ang)

            );

}

float3x3 RotX(float ang)
{
    return float3x3

        (
            1, 0, 0,
            0, cos(ang), -sin(ang),
            0, sin(ang), cos(ang)

            );

}

float3x3 RotZ(float ang)
{
    return float3x3

        (
            cos(ang), -sin(ang), 0,
            sin(ang), cos(ang), 0,
            0, 0, 1

            );

}

sampler2D _WindDistortionMap; //So don't use texture 2d -- make the name of the sampler itself the name of the texture to directly sample from it. sampler2D 
float4 _WindDistortionMap_ST; //PROVIDED BY THE UNITY ENGINE FOR ALL TEXTURES W/ TILING AND OFFSET APPLIED _ST at the end 


//REVELATION!!!! THE REASON WHY THE GEOM SHDER ISNT DOING SHIT IS BECAUSE POSITIONCS IS BEING SET IN VERTEX WHICH RUNS BEFORE THE FRAGMENT!!!! SO YOU NEED TO COMPUTE THAT IN GEOM!

[maxvertexcount(10)]
void LitPassGeom(triangle Varyings input[3], inout TriangleStream<Varyings> outStream)
{

    if (input[0].color.g < 0.1f || input[1].color.g < 0.1f || input[2].color.g < 0.1f)
    {
        
        //outStream.RestartStrip();
        return;
        

    }
    else {
        
    for (int i = 0; i <3; i++)
    {

        Varyings o = input[i];

        //float2 uv = input[i].positionOS.xy * _WindDistortionMap_ST.xy * _Time.x + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;

        float2 uv = (input[i].positionOS.xy*_Time.xy*_WindFrequency);

        //TO GET BETWEEN -1 & 1 (uv * 2 - 1)

        float4 windSample = tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)*2-1)*_WindStrength; //.Sample isn't allowed in vertex & geom (tex2DLod has to be used!)

        float3 rotatedTangent = normalize(mul(o.tangentWS, RotY(rand(o.positionWSAndFogFactor) * 90)));

        float3 rotatedNormalZ = mul(o.normalWS, RotZ(windSample.x ));

        float3 rotatedNormal = (mul(rotatedNormalZ, RotX(windSample.y)));

        
        float randH = rand(rotatedTangent) * 0.15;

        Varyings o2 = input[i];

        float3 newObjectSpace = (rotatedTangent * (Base + randH) + o.positionWSAndFogFactor.xyz);
        o2.positionCS = TransformWorldToHClip(newObjectSpace);

        Varyings o3 = input[i];

        float3 newObjectSpace2 = ((rotatedNormal * (Height + randH) + rotatedTangent * (Base + randH)) + o.positionWSAndFogFactor.xyz);
        o3.positionCS = TransformWorldToHClip(newObjectSpace2);

    

        Varyings o4 = input[i];

        float3 newObjectSpace3 = ((rotatedNormal) * (Height + randH) + o.positionWSAndFogFactor.xyz);

     

        o4.positionCS = TransformWorldToHClip(newObjectSpace3);

        float3 norm = mul(rotatedTangent,RotY( PI / 2));

        o.normalWS = norm;
        o2.normalWS =norm;
        o3.normalWS =norm;
        o4.normalWS =norm;

        o4.uv = TRANSFORM_TEX(float2(0, 1), _BaseMap);
        o3.uv = TRANSFORM_TEX(float2(1, 1), _BaseMap);
        o2.uv = TRANSFORM_TEX(float2(1, 0), _BaseMap);
        o.uv = TRANSFORM_TEX(float2(0, 0), _BaseMap);


        outStream.Append(o4);
        outStream.Append(o3);
        outStream.Append(o);

        outStream.RestartStrip();

        outStream.Append(o3);
        outStream.Append(o2);
        outStream.Append(o);
        outStream.RestartStrip();

    }
    }

}


float4 TransformWorldToShadowCoords(float3 positionWS)
{
#ifdef _MAIN_LIGHT_SHADOWS_CASCADE
    half cascadeIndex = ComputeCascadeIndex(positionWS);
#else
    half cascadeIndex = 0;
#endif

    return mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));
}


float DoublePlaned;
float _ReceiveShadows;

texture2D _AlphaMap;
float4 _AlphaMap_ST;
sampler sampler_AlphaMap;

//use SV_IsFrontFace to detect what direction you are looking at it from since Cull Off and it is 2D so you can get smooth and correct lighting 
half4 LitPassFragment(Varyings input, bool vf : SV_IsFrontFace) : SV_Target
{

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uvLM, surfaceData);


    half3 normalWS = input.normalWS;

    
    normalWS = normalize(normalWS);

    //This is very important and controls lighting, if it isn't reversed then it has same lighting on two sides
    if (vf == true) {
        normalWS = -normalWS;
    }

    half3 bakedGI = SampleSH(normalWS);
    float3 positionWS = input.positionWSAndFogFactor.xyz;
    half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);
    
    Light mainLight = GetMainLight();
    if (_ReceiveShadows == 1) {
    #if SHADOWS_SCREEN
            float4 clipPos = TransformWorldToHClip(input.positionWS);
            float4 shadowCoord = ComputeScreenPos(clipPos);
    #else
            float4 shadowCoord = TransformWorldToShadowCoords(positionWS);
    #endif
            mainLight = GetMainLight(shadowCoord);
        }
        else {


    #ifdef _MAIN_LIGHT_SHADOWS

            mainLight = GetMainLight(input.shadowCoord);

    #else

            mainLight = GetMainLight();

    #endif
        }


    
    
    half3 color = GlobalIllumination(brdfData, bakedGI, surfaceData.occlusion, normalWS, viewDirectionWS);


    
    //Physically Based (if you need specular, metalic etc. ) : color += LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirectionWS) * _LightAffectance;
    
    float3 normalLight = LightingLambert(mainLight.color, mainLight.direction, normalWS) * _LightAffectance;
    
    float3 inverseNormalLight = LightingLambert(mainLight.color, mainLight.direction, -normalWS) * _TranslucencyFactor;
    
    
#ifdef ALPHAMAP
    float v2 = _AlphaMap.Sample(sampler_AlphaMap, input.uv).a;
    color += normalLight + inverseNormalLight*clamp((1-v2),0.2,1);
#else
    color += normalLight + inverseNormalLight;
#endif

//Tint
    color += _Vect.rgb;
    
    //Translucency Factor
    
    
    
    //RENDER SHADOW MAP : return float4(mainLight.shadowAttenuation, mainLight.shadowAttenuation, mainLight.shadowAttenuation, 1);

    float fogFactor = input.positionWSAndFogFactor.w;

    // Mix the pixel color with fogColor. You can optionaly use MixFogColor to override the fogColor
    // with a custom one.
    float v = _BaseMap.Sample(sampler_BaseMap, input.uv).a;

    float4 darker = _Darker;

    color = lerp(color, darker, 1 - input.uv.y);
    
    color = lerp(darker,color,clamp(mainLight.shadowAttenuation+_ShadowAffectance,0,1));
    //return float4(v, v, v, v);
    
    color = MixFog(color, fogFactor);
    
    //return float4(1,1,1,v);

    //Just 'skip' this render allowing for transparency
    clip(v - AlphaCutoff);


    return half4(color, v);
}