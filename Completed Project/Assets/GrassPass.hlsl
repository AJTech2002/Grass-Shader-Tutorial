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


/*

	*/

[maxvertexcount(10)]
void LitPassGeom(triangle Varyings input[3], inout TriangleStream<Varyings> outStream)
{

	if (input[0].color.g < 0.1f || input[1].color.g < 0.1f || input[2].color.g < 0.1f)
	{

		return;

	}
	else {

		int i = 0;
		Varyings o = input[i];
		float2 uv = (input[i].positionOS.xy * _Time.xy * _WindFrequency);

		float4 windSample = tex2Dlod(_WindDistortionMap, float4(uv, 0, 0) ) * _WindStrength;

		float3 rotatedTangent = normalize(mul(o.tangentWS, RotY(rand(o.positionWSAndFogFactor.xyz) * 90)));

		float3 rotatedNormalZ = mul(o.normalWS, RotZ(windSample.x));

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

		float3 norm = mul(rotatedTangent, RotY(PI / 2));

		o.normalWS = norm;
		o2.normalWS = norm;
		o3.normalWS = norm;
		o4.normalWS = norm;

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


float4 TransformWorldToShadowCoords(float3 positionWS)
{
//Explain a bit about Cascading
#ifdef _MAIN_LIGHT_SHADOWS_CASCADE
	half cascadeIndex = ComputeCascadeIndex(positionWS);
#else
	half cascadeIndex = 0;
#endif

	//Converting the world to shadow coordinates and passing in cascade index (matrix multiply to transform)
	return mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));
}


float DoublePlaned;
float _ReceiveShadows;

texture2D _AlphaMap;
sampler sampler_AlphaMap;


half4 LitPassFragment(Varyings input, bool vf : SV_IsFrontFace) : SV_Target
{

	////Setting up surface properties so that it can tell GI how to register it
	SurfaceData surfaceData;
	InitializeStandardLitSurfaceData(input.uvLM, surfaceData);

	BRDFData brdfData;
	InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

	//Setting up global illumination and normals 
	half3 normalWS = input.normalWS;
	normalWS = normalize(normalWS);

	//Flipping Normals
	if (vf == true) {
		normalWS = -normalWS;
	}

	float3 positionWS = input.positionWSAndFogFactor.xyz;
	half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);

	//Calculating the base color
	half3 bakedGI = SampleSH(normalWS);
	//half3 color = GlobalIllumination(brdfData, bakedGI, surfaceData.occlusion, normalWS, viewDirectionWS);

	half3 color = (0, 0, 0);

	Light mainLight;

	//Introduce Recieve Shadows
	 if (_ReceiveShadows == 1) {
	#if SHADOWS_SCREEN
		//If shadows are in screen space then you can simply calculate the screen space or HClip of the current vertex and then you can get the shadow coordinate
		float4 clipPos = TransformWorldToHClip(input.positionWS);
		float4 shadowCoord = ComputeScreenPos(clipPos);
	#else
		 //If it isn't we have to take a different approach
		float4 shadowCoord = TransformWorldToShadowCoords(positionWS);
	#endif
		
		//We can get the mainlight with the given shadowCoordinate and then it will give us properties such as the attenuation
		mainLight = GetMainLight(shadowCoord);
	 }
	 else {
		 
		#ifdef _MAIN_LIGHT_SHADOWS
			mainLight = GetMainLight(input.shadowCoord);
		#else
			mainLight = GetMainLight();
		#endif
	 }

	 //Simple lighting based on the normal direction & Introduce Light Affectance and Transluecency Factor (both 0.05)
	float3 normalLight = LightingLambert(mainLight.color, mainLight.direction, normalWS) * _LightAffectance;

	//Lighting based on what the other side will get 
	float3 inverseNormalLight = LightingLambert(mainLight.color, mainLight.direction, -normalWS) * _TranslucencyFactor;

	//Add the tint color (name this tint...)
	color += _Vect.rgb+normalLight+inverseNormalLight;

	//How much it should be affected by fog (held in w)
	float fogFactor = input.positionWSAndFogFactor.w;

	//Sampling base map for texture and getting the alpha value only not color
	float v = _BaseMap.Sample(sampler_BaseMap, input.uv).a;

	//The bottom value
	float4 darker = _Darker;

	//Lerping from the color down to darker based on UV to get self shadowing effect
	color = lerp(color, darker, 1 - input.uv.y);

	//Now lerping from color -> darkness based on the shadow attenuation (Shadow Strength = 0.35)
	color = lerp(darker,color,clamp(mainLight.shadowAttenuation + _ShadowAffectance,0,1));

	//Mix the fog with the color
	color = MixFog(color, fogFactor);

	//Clip or just redact pixels
	clip(v - AlphaCutoff);

	//return done
	return half4(color, v);
}