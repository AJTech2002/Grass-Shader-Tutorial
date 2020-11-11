//https://pastebin.com/Ey01tzLq (SRP Batching Support + ShadowCaster support)

Shader "Unlit/URPPlanedDepth"
{

    Properties
    {
        Height("Height", Float) = 1.0
        Base("Base",Float) = 1.0
        DoublePlaned("Double Planes",Float)=0.0
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength ("Wind Strength",Float)=0.0
        
            _ShadowAffectance("Shadow Affectance",Float)=0.2
        Speed("Speed",Float) = 1.0
        _Vect("Vector",Color) = (0.6,0.6,0.6,1)
        _Darker("Darker",Color) = (0.5,0.5,0.5,1)
        
            _LightAffectance("Light Affectance",Float) = 0.5
        _TranslucencyFactor("Translucency Factor", Float) = 0.5
        
            Ang("Angle",Float) = 1.0
        // Specular vs Metallic workflow
        AlphaCutoff("AlphaCut",Float) = 0.5

        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0

        GroundTexture ("Ground",2D) = "white" {}

        [MainColor] _BaseColor("Color", Color) = (0.5,0.5,0.5,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5


            // Blending state
             _Surface("__surface", Float) = 0.0
             _Blend("__blend", Float) = 0.0
             _AlphaClip("__clip", Float) = 0.0
             _SrcBlend("__src", Float) = 1.0
             _DstBlend("__dst", Float) = 0.0
             _ZWrite("__zw", Float) = 1.0
             _Cull("__cull", Float) = 2.0

            _ReceiveShadows("Receive Shadows", Float) = 1.0
            [Space]
            _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
            _VertexColorTesselation ("Based on Vertex Color (0,1)",Float) = 0
            // Editmode props
            [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300
        Pass
        {
            
            Tags {"LightMode" = "DepthOnly"}
            
            ZWrite On
            ColorMask 0
            Cull Off
            
            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma multi_compile _ WRITE_NORMAL_BUFFER
            #pragma multi_compile _ WRITE_MSAA_DEPTH
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_instancing
            
            #pragma require geometry

            #pragma geometry LitPassGeom
            #pragma vertex LitPassVertex
            #pragma fragment DepthPassFragment
              #pragma hull hull
            #pragma domain domain
            #define SHADOW
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #include "GrassPass.hlsl"

          
            #include "Tesselator.hlsl"


            half4 DepthPassFragment(Varyings input) : SV_TARGET{
                //Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }

            ENDHLSL
        }
        
        //Shadow Caster Pass (This is not preferable as the shadows cast on themselves causing entirely shadowed grass)
        /* 
        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            Cull Off

            ZWrite On
            ZTest LEqual

            ColorMask 0

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
    
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma require geometry

            #pragma geometry LitPassGeom
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            

            #include "GrassPass.hlsl"

           

            ENDHLSL
        }
        */

        //The actual grass
        Pass
        {
            Name "GrassPass"
            Tags { "RenderType" = "Opaque" "LightMode" = "UniversalForward" }
            
            //ONLY FOR FADE: Blend SrcAlpha OneMinusSrcAlpha
            Blend[_SrcBlend][_DstBlend]
            ZWrite [_ZWrite]
            Cull Off

            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.0

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_ON
            //#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS

            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma require geometry

            #pragma geometry LitPassGeom
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma hull hull
            #pragma domain domain

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #include "GrassPass.hlsl"
            #include "Tesselator.hlsl"
            ENDHLSL

        }
       
    }

}
