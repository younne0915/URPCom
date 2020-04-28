Shader "Hidden/Universal Render Pipeline/CameraMotionBlur"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

        TEXTURE2D_X(_MainTex);
        TEXTURE2D_X_FLOAT(_CameraDepthTexture);

        float4x4 _ViewProjM;
        float4x4 _PrevViewProjM;
        float _Intensity;
        float _Clamp;
        float4 _MainTex_TexelSize;

        struct VaryingsCMB
        {
            float4 positionCS    : SV_POSITION;
            float4 uv            : TEXCOORD0;
            UNITY_VERTEX_OUTPUT_STEREO
        };
		
        VaryingsCMB VertCMB(Attributes input)
        {
            VaryingsCMB output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			//转化到齐次裁剪坐标系
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);


            float4 projPos = output.positionCS * 0.5;
            projPos.xy = projPos.xy + projPos.w;

            output.uv.xy = input.uv;
            output.uv.zw = projPos.xy;

            return output;
        }

        float2 ClampVelocity(float2 velocity, float maxVelocity)
        {
            float len = length(velocity);
            return (len > 0.0) ? min(len, maxVelocity) * (velocity * rcp(len)) : 0.0;
        }

        // Per-pixel camera velocity
        float2 GetCameraVelocity(float4 uv)
        {

			//采样范围是(0, 1)
            float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv.xy).r;

        #if UNITY_REVERSED_Z
            depth = 1.0 - depth;
        #endif

			//映射到(-1, 1)
            depth = 2.0 * depth - 1.0;

			/*
			float3 ComputeViewSpacePosition(float2 positionNDC, float deviceDepth, float4x4 invProjMatrix)
{
	float4 positionCS = ComputeClipSpacePosition(positionNDC, deviceDepth);

	//invProjMatrix是其次裁剪坐标系转为视觉坐标系
	float4 positionVS = mul(invProjMatrix, positionCS);
	// The view space uses a right-handed coordinate system.
	positionVS.z = -positionVS.z;
	return positionVS.xyz / positionVS.w;
}

float4 ComputeClipSpacePosition(float2 positionNDC, float deviceDepth)
{
	//把（0,1）映射到（-1,1），positionCS是
	float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);

#if UNITY_UV_STARTS_AT_TOP
	// Our world space, view space, screen space and NDC space are Y-up.
	// Our clip space is flipped upside-down due to poor legacy Unity design.
	// The flip is baked into the projection matrix, so we only have to flip
	// manually when going from CS to NDC and back.
	positionCS.y = -positionCS.y;
#endif

	return positionCS;
}

			*/

            float3 viewPos = ComputeViewSpacePosition(uv.zw, depth, unity_CameraInvProjection);
            float4 worldPos = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);
            float4 prevPos = worldPos;

            float4 prevClipPos = mul(_PrevViewProjM, prevPos);
            float4 curClipPos = mul(_ViewProjM, worldPos);

            float2 prevPosCS = prevClipPos.xy / prevClipPos.w;
            float2 curPosCS = curClipPos.xy / curClipPos.w;

            return ClampVelocity(prevPosCS - curPosCS, _Clamp);
        }

        float3 GatherSample(float sampleNumber, float2 velocity, float invSampleCount, float2 centerUV, float randomVal, float velocitySign)
        {
            float  offsetLength = (sampleNumber + 0.5) + (velocitySign * (randomVal - 0.5));
            float2 sampleUV = centerUV + (offsetLength * invSampleCount) * velocity * velocitySign;
            return SAMPLE_TEXTURE2D_X(_MainTex, sampler_PointClamp, sampleUV).xyz;
        }

        half4 DoMotionBlur(VaryingsCMB input, int iterations)
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 uv = UnityStereoTransformScreenSpaceTex(input.uv.xy);
            float2 velocity = GetCameraVelocity(float4(uv, input.uv.zw)) * _Intensity;
            float randomVal = InterleavedGradientNoise(uv * _MainTex_TexelSize.zw, 0);
            float invSampleCount = rcp(iterations * 2.0);

            half3 color = 0.0;

            UNITY_UNROLL
            for (int i = 0; i < iterations; i++)
            {
                color += GatherSample(i, velocity, invSampleCount, uv, randomVal, -1.0);
                color += GatherSample(i, velocity, invSampleCount, uv, randomVal,  1.0);
            }

            return half4(color * invSampleCount, 1.0);
        }

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "Camera Motion Blur - Low Quality"

            HLSLPROGRAM

                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    return DoMotionBlur(input, 2);
                }

            ENDHLSL
        }

        Pass
        {
            Name "Camera Motion Blur - Medium Quality"

            HLSLPROGRAM

                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    return DoMotionBlur(input, 3);
                }

            ENDHLSL
        }

        Pass
        {
            Name "Camera Motion Blur - High Quality"

            HLSLPROGRAM

                #pragma vertex VertCMB
                #pragma fragment Frag

                half4 Frag(VaryingsCMB input) : SV_Target
                {
                    return DoMotionBlur(input, 4);
                }

            ENDHLSL
        }
    }
}
