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
   
    float3 posObj = input.positionOS.xyz;
    
    VertexPositionInputs vertexInput = GetVertexPositionInputs(posObj);

    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    // Computes fog factor per-vertex.
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;

    output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
    output.normalWS = vertexNormalInput.normalWS;
    output.tangentWS = vertexNormalInput.tangentWS;

#ifdef _NORMALMAP

    output.bitangentWS = vertexNormalInput.bitangentWS;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
  
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

sampler2D _WindDistortionMap; 
float4 _WindDistortionMap_ST; 


[maxvertexcount(10)]
void LitPassGeom(triangle Varyings input[3], inout TriangleStream<Varyings> outStream)
{

    if (input[0].color.g < 0.1f || input[1].color.g < 0.1f || input[2].color.g < 0.1f)
    {
        
        return;
        
    }
    else {
        
    for (int i = 0; i <3; i++)
    {

        Varyings o = input[i];

        

        float2 uv = (input[i].positionOS.xy*_Time.xy*_WindFrequency);

        float4 windSample = tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)*2-1)*_WindStrength; 

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


half4 LitPassFragment(Varyings input, bool vf : SV_IsFrontFace) : SV_Target
{

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uvLM, surfaceData);


    half3 normalWS = input.normalWS;

    
    normalWS = normalize(normalWS);

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

    float3 normalLight = LightingLambert(mainLight.color, mainLight.direction, normalWS) * _LightAffectance;
    
    float3 inverseNormalLight = LightingLambert(mainLight.color, mainLight.direction, -normalWS) * _TranslucencyFactor;
    
    
#ifdef ALPHAMAP
    float v2 = _AlphaMap.Sample(sampler_AlphaMap, input.uv).a;
    color += normalLight + inverseNormalLight*clamp((1-v2),0.2,1);
#else
    color += normalLight + inverseNormalLight;
#endif
    color += _Vect.rgb;
  
    float fogFactor = input.positionWSAndFogFactor.w;

    float v = _BaseMap.Sample(sampler_BaseMap, input.uv).a;

    float4 darker = _Darker;

    color = lerp(color, darker, 1 - input.uv.y);
    
    color = lerp(darker,color,clamp(mainLight.shadowAttenuation+_ShadowAffectance,0,1));
  
    color = MixFog(color, fogFactor);
  
    clip(v - AlphaCutoff);


    return half4(color, v);
}