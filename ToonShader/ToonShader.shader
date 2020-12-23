Shader "Toon/ToonShader"
{
    Properties
    {
        //[Enum(UnityEditor.BlendMode)] _Mode ("Blend Mode", Int) = 0
        [KeywordEnum(Material, Vertex, Multiply)]
        _ColorMethod ("Coloring Method", Float) = 0
        [MainColor] _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap ("BaseMap", 2D) = "white" { }
        [HDR]_EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)
        [Emission] _EmissionMap ("EmissionColor", 2D) = "white" { }
        _SpecGlossMap ("Specular Map", 2D) = "white" { }
        [Normal][NoScaleOffset] _BumpMap ("NormalMap", 2D) = "bump" { }
        _NormalIntensity ("Normal Map Intensity", float) = 1
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _MidPoint ("Shade Mid Point", Range(0, 1)) = 0.3
        
        /*
        [Enum(UnityEngine.Rendering.CullMode)] _Culling ("Cull Mode", Int) = 2
        [Enum(None, 0, Alpha, 1, Red, 8, Green, 4, Blue, 2, RGB, 14, RGBA, 15)] _ColorMask ("Color Mask", Int) = 14
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
        [Toggle] _ZWrite ("ZWrite", Int) = 0
        
        [IntRange] _StencilRef ("Stencil Reference", Range(0, 15)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comparison", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp ("Stencil Operation", Float) = 0
        */
    }
    
    SubShader
    {
        Pass
        {
            Name "Base"
            Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #pragma target 3.0
            #pragma prefer_hlslcc gles
            
            //Excluding Variants
            //#pragma exclude_renderers d3d11_9x d3d11 xboxone ps4 n3ds wiiu
            
            #pragma vertex vert
            #pragma fragment frag
            
            //URP Keywords for shadows
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            
            //Support for additional lights
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
            //Alpha operations
            #pragma shader_feature _ _ALPHATEST_ON
            #pragma shader_feature _ _ALPHABLEND_ON
            #pragma shader_feature _ _ALPHAPREMULTIPLY_ON
            
            //URP Keywords for Lightmaping
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            
            //Enable fog
            #pragma multi_compile_fog
            
            //Shader Keywords for Customization
            #pragma shader_feature _COLORMETHOD_MATERIAL _COLORMETHOD_VERTEX _COLORMETHOD_MULTIPLY
            #pragma shader_feature _ _NORMALMAP
            #pragma shader_feature _ _SPECULAR
            #pragma shader_feature _ _REFLECTION
            #pragma shader_feature _ _ALPHA_CLIP
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            
            #include "ShaderHelper.hlsl"
            
            struct Attributes
            {
                float4 positionOS: POSITION;
                float2 uv: TEXCOORD0;
                float3 normalOS: NORMAL;
                float4 tangentOS: TANGENT;
                float4 color: COLOR;
                #if LIGHTMAP_ON
                    float2 uvLightmap: TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 uv: TEXCOORD0;
                float2 uvLM: TEXCOORD1;
                float4 positionWSAndFogFactor: TEXCOORD2;
                float4 positionHCS: SV_POSITION;
                float3 normalWS: NORMAL;
                float3 tangentWS: TANGENT;
                float3 bitangentWS: TEXCOORD3;
                float4 vertexColor: COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            
            #ifdef _NORMALMAP
                TEXTURE2D(_BumpMap);
                SAMPLER(sampler_BumpMap);
            #endif
            
            #if defined _SPECULAR || defined _REFLECTION
                TEXTURE2D(_SpecGlossMap);
                SAMPLER(sampler_SpecGlossMap);
            #endif
            
            //Defining parameters in a per-material constant buffer to utilize srp batching
            CBUFFER_START(UnityPerMaterial)
            half4 _BaseMap_ST;
            #ifdef _NORMALMAP
                half4 _BumpMap_ST;
            #endif
            #if defined _SPECULAR || defined _REFLECTION
                half4 _SpecGlossMap_ST;
            #endif
            half _NormalIntensity;
            half4 _BaseColor;
            half _Smoothness;
            half _MidPoint;
            half4 _EmissionColor;
            half _Cutoff;
            CBUFFER_END
            
            Varyings vert(Attributes i)
            {
                //Initialize varyings as 0
                Varyings o = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i, o);
                
                // GetVertexPositionInputs computes position in different spaces (ViewSpace, WorldSpace, Homogeneous Clip Space)
                VertexPositionInputs positionInputs = GetVertexPositionInputs(i.positionOS.xyz);
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);
                //Positions + fog factor
                o.positionHCS = positionInputs.positionCS;
                
                //FogFactor
                half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                o.positionWSAndFogFactor = float4(positionInputs.positionWS, fogFactor);
                //Normals
                o.normalWS = vertexNormalInput.normalWS;
                o.tangentWS = vertexNormalInput.tangentWS;
                o.bitangentWS = vertexNormalInput.bitangentWS;
                //UV(xy) and ScreenUV(zw)
                o.uv = float4(TRANSFORM_TEX(i.uv, _BaseMap), ComputeScreenPos(i.positionOS).xy);
                //Passthrough vertex color.
                o.vertexColor = i.color;
                //Outputting Lightmap UV
                #if LIGHTMAP_ON
                    o.uvLM = i.uvLightmap.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                return o;
            }
            
            half4 frag(Varyings i): SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                
                //Initialize final color value.
                half4 color = 0;
                
                //Normal calculations
                #ifdef _NORMALMAP
                    half3 normalT = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv.xy), _NormalIntensity);
                    half3 normalWS = TransformTangentToWorld(normalT, half3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz));
                #else
                    half3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                #endif
                
                #if defined _SPECULAR || defined _REFLECTION
                    half4 specularGloss = SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, i.uv.xy);
                    specularGloss.a = _Smoothness;
                #endif
                
                //Normalize the vertex normal direciton to get better fragment normal direction.
                normalWS = normalize(normalWS);
                
                //Recieve view direction
                half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - i.positionWSAndFogFactor.xyz);
                
                //Get Albedo depending on the colormethod preference.
                #ifdef _COLORMETHOD_MATERIAL
                    half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv.xy) * _BaseColor;
                    
                #elif _COLORMETHOD_VERTEX
                    half4 albedo = i.vertexColor;
                #elif _COLORMETHOD_MULTIPLY
                    half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv.xy) * _BaseColor * i.vertexColor;
                #endif
                
                //Material Alpha
                color.a = albedo.a;
                #ifdef _ALPHA_CLIP
                    clip(color.a - 0.5);
                #endif
                
                //Compute Global Illumination
                half3 bakedGI = SampleSH(i.normalWS);
                
                // shadowCoord is position in shadow light space
                half4 shadowCoord = TransformWorldToShadowCoord(i.positionWSAndFogFactor.xyz);
                Light mainLight = GetMainLight(shadowCoord);
                
                //Compute direct light contribution.
                color.rgb += CustomDiffuseLighting(mainLight, albedo, normalWS, viewDirectionWS, bakedGI, _MidPoint);
                #ifdef _SPECULAR
                    color.rgb += LightingSpecular(mainLight.color, mainLight.direction, normalWS, viewDirectionWS, specularGloss, 100 * _Smoothness + 1) * _Smoothness;
                #endif
                
                //Additional Lights
                #ifdef _ADDITIONAL_LIGHTS
                    
                    int additionalLightsCount = GetAdditionalLightsCount();
                    for (int l = 0; l < additionalLightsCount; ++ l)
                    {
                        Light light = GetAdditionalLight(l, i.positionWSAndFogFactor.xyz);
                        //Compute additional light contribution
                        color.rgb += CustomDiffuseLighting(light, albedo, normalWS, viewDirectionWS, bakedGI, _MidPoint);
                        #ifdef _SPECULAR
                            color.rgb += LightingSpecular(light.color, light.direction, normalWS, viewDirectionWS, specularGloss, 100 * _Smoothness + 1) * _Smoothness;
                        #endif
                    }
                #endif
                
                //Add Global Illumination
                CustomMixGI(color, albedo, bakedGI, normalWS, viewDirectionWS);
                
                //Add Reflections
                #ifdef _REFLECTION
                    half3 reflection = LightingReflection(albedo, specularGloss * _Smoothness, viewDirectionWS, normalWS);
                    color.rgb += reflection;
                #endif
                
                color += SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv.xy) * _EmissionColor;
                
                //Finally mixing the fog
                color.rgb = MixFog(color.rgb, i.positionWSAndFogFactor.w);
                //color.rgb = i.positionWSAndFogFactor.w;
                
                return color;
            }
            ENDHLSL
            
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            Cull[_Cull]
            
            HLSLPROGRAM
            
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _GLOSSINESS_FROM_BASE_ALPHA
            
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            half4 _BaseMap_ST;
            #ifdef _NORMALMAP
                half4 _BumpMap_ST;
            #endif
            #if defined _SPECULAR || defined _REFLECTION
                half4 _SpecGlossMap_ST;
            #endif
            half _NormalIntensity;
            half4 _BaseColor;
            half _Smoothness;
            half _MidPoint;
            half4 _EmissionColor;
            half _Cutoff;
            CBUFFER_END

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
            
        }
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
    //CustomEditor "UnityEditor.CustomShaderGUI"
}