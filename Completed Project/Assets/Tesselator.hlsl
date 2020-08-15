#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
#define UNITY_CAN_COMPILE_TESSELLATION 1
#   define UNITY_domain                 domain
#   define UNITY_partitioning           partitioning
#   define UNITY_outputtopology         outputtopology
#   define UNITY_patchconstantfunc      patchconstantfunc
#   define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

struct TessellationFactors 
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};


float _TessellationUniform;
int _VertexColorTesselation;

TessellationFactors patchConstantFunction (InputPatch<Varyings, 3> patch)
{
	TessellationFactors f;
	
	if (_VertexColorTesselation == 0) {
		f.edge[0] = _TessellationUniform;
		f.edge[1] = _TessellationUniform;
		f.edge[2] = _TessellationUniform;
		f.inside = _TessellationUniform;
	}
	else {

		float value = lerp(1, _TessellationUniform, (patch[0].color.g + patch[1].color.g + patch[2].color.g) / 3);

		f.edge[0] = value;
		f.edge[1] = value;
		f.edge[2] = value;
		f.inside = value;
	}
	return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
Varyings hull (InputPatch<Varyings, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

[UNITY_domain("tri")]
Varyings domain(TessellationFactors factors, OutputPatch<Varyings, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
	Varyings v;

	#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

	MY_DOMAIN_PROGRAM_INTERPOLATE(positionWSAndFogFactor)
	MY_DOMAIN_PROGRAM_INTERPOLATE(positionCS)
	MY_DOMAIN_PROGRAM_INTERPOLATE(normalWS)
	MY_DOMAIN_PROGRAM_INTERPOLATE(tangentWS)

		MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS)


		MY_DOMAIN_PROGRAM_INTERPOLATE(uv)

		MY_DOMAIN_PROGRAM_INTERPOLATE(uvLM)
		MY_DOMAIN_PROGRAM_INTERPOLATE(normalOS)
		MY_DOMAIN_PROGRAM_INTERPOLATE(color)


	return v;
}