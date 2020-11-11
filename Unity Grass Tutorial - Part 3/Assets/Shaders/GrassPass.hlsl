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

//Properties
float _Height;
float _Base;
float4 _Tint;
float _RecieveShadows;

float _LightPower;
float _TPower;

//VERTEX PASS
Varyings LitPassVertex(Attributes input)
{
    Varyings output;

    output.color = input.color;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

    output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;


    output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
    output.positionCS = vertexInput.positionCS;
    output.positionOS = input.positionOS;
    
    output.normalWS = vertexNormalInput.normalWS;
    output.tangentWS = vertexNormalInput.tangentWS;

    #ifdef _NORMALMAP
        output.bitangentWS = vertexNormalInput.bitangentWS;
    #endif

    #ifdef _MAIN_LIGHT_SHADOWS
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    return output;
}

float3x3 RotY(float ang)
{
    return float3x3
    (
        cos(ang), 0, sin(ang),
        0,1,0,
        -sin(ang),0,cos(ang)
    );
}

float rand(float3 co)
{
    return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}

[maxvertexcount(6)]
void LitPassGeom(triangle Varyings input[3], inout TriangleStream<Varyings> outStream)
{

    float3 basePos = (input[0].positionWSAndFogFactor.xyz + input[1].positionWSAndFogFactor.xyz + input[2].positionWSAndFogFactor.xyz) / 3;

    Varyings o = input[0];

    float3 rotatedTangent = normalize(mul(o.tangentWS, RotY(rand(o.positionWSAndFogFactor.xyz) * 90)));

    float3 oPos = (basePos - rotatedTangent *_Base);
    o.positionCS = TransformWorldToHClip(oPos);

    Varyings o2 = input[0];
    float3 o2Pos = (basePos + rotatedTangent * _Base);
    o2.positionCS = TransformWorldToHClip(o2Pos);

    Varyings o3 = input[0];
    float3 o3Pos = (basePos + rotatedTangent * _Base + o3.normalWS*_Height);
    o3.positionCS = TransformWorldToHClip(o3Pos);

    Varyings o4 = input[0];
    float3 o4Pos = (basePos - rotatedTangent * _Base + o3.normalWS * _Height);
    o4.positionCS = TransformWorldToHClip(o4Pos);

    float3 newNormal = mul(rotatedTangent, RotY(PI / 2));

    o4.uv = TRANSFORM_TEX(float2(0, 1), _BaseMap);
    o3.uv = TRANSFORM_TEX(float2(1, 1), _BaseMap);
    o2.uv = TRANSFORM_TEX(float2(1, 0), _BaseMap);
    o.uv = TRANSFORM_TEX(float2(0, 0), _BaseMap);

    o.normalWS = newNormal;
    o2.normalWS = newNormal;
    o3.normalWS = newNormal;
    o4.normalWS = newNormal;

    outStream.Append(o4);
    outStream.Append(o3);
    outStream.Append(o);

    outStream.RestartStrip();

    outStream.Append(o3);
    outStream.Append(o2);
    outStream.Append(o);

    outStream.RestartStrip();

}

float4 TransformWorldToShadowCoords(float3 positionWS)
{
    half cascadeIndex = ComputeCascadeIndex(positionWS);
    return mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));
}

float _ShadowPower;
float _AlphaCutoff;
float4 _Darker;

half4 LitPassFragment(Varyings input, bool vf : SV_IsFrontFace) : SV_Target
{
    half3 normalWS = input.normalWS;

    normalWS = normalize(normalWS);

    if (vf == true)
    {
        normalWS = -normalWS;
    }

    float3 positionWS = input.positionWSAndFogFactor.xyz;

    half3 color = (0, 0, 0);

    Light mainLight;

    float4 shadowCoord = TransformWorldToShadowCoords(positionWS);

    mainLight = GetMainLight(shadowCoord);

    float3 normalLight = LightingLambert(mainLight.color, mainLight.direction, normalWS) * _LightPower;
    float3 inverseNormalLight = LightingLambert(mainLight.color, mainLight.direction, -normalWS) * _TPower;

    color = _Tint + normalLight + inverseNormalLight;

    color = lerp(color, _Darker, 1 - input.uv.y);

    color = lerp(_Darker, color, clamp(mainLight.shadowAttenuation + _ShadowPower, 0, 1));


    float fogFactor = input.positionWSAndFogFactor.w;

    color = MixFog(color, fogFactor);

    float a = _BaseMap.Sample(sampler_BaseMap, input.uv).a;

    clip(a - _AlphaCutoff);


    return half4(color, 1);
}