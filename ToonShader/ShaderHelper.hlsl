//This is to prevent the file to be included more than once
#ifndef SHADER_HELPER
    #define SHADER_HELPER

    half3 CustomDiffuseLighting(Light light, half4 albedo, half3 normalWS, half3 viewDirectionWS, half3 GI,half midPoint)
    {
        half NdotL = dot(normalWS, light.direction);
        half diff = saturate(NdotL);

        //Toon Shading
        
        diff = step(midPoint,diff);
        half fDiff = fwidth(diff);
        diff = lerp(diff,0.5,fDiff);
        
        //distanceAttenuation is always 1 for directional lighting.
        half atten = light.shadowAttenuation * light.distanceAttenuation;
        //This little trick is to achieve an unlit look if the lights are set to cast 0 shadow.
        half shading = lerp(light.distanceAttenuation, diff * atten, GetMainLightShadowStrength());
        return shading * albedo.rgb * light.color;
    }

    half3 CustomLightingSpecular(Light light, half3 normalWS, half3 viewDirectionWS, half smoothness)
    {
        //Calculate Specular Lighting
        half3 halfVec = SafeNormalize(half3(light.direction) + half3(viewDirectionWS));
        half NdotH = saturate(dot(normalWS, normalize(halfVec)));
        NdotH = pow(NdotH, smoothness * 300 + 0.1) * smoothness;
        half3 specular = light.color * NdotH;
        specular *= light.shadowAttenuation * light.distanceAttenuation;
        return specular;
    }

    void CustomMixGI(inout half4 color,half4 albedo, half3 GI, half3 normalWS, half3 viewDirectionWS)
    {
        color.rgb = color.rgb + albedo.rgb * GI;
    }

    half3 LightingReflection(half3 albedo, half Smoothness, half3 viewDirectionWS, half3 normalWS)
    {
        half fresnel = dot(viewDirectionWS, normalWS);
        half3 reflectVec = -reflect(viewDirectionWS, normalWS);
        half3 reflection = GlossyEnvironmentReflection(reflectVec, fresnel * (1 - Smoothness), (Smoothness + (1 - fresnel)) * 0.5);
        return lerp(reflection, albedo, 0.5);
    }

#endif