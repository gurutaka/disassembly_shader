// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Geometry/Disassembly"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _Destruction("Destruction Factor", Range(0.0, 1.0)) = 0.0
        _ScaleFactor("Scale Factor", Range(0.0, 1.0)) = 1.0
        _RotationFactor("Rotation Factor", Range(0.0, 1.0)) = 1.0
        _PositionFactor("Position Factor", Range(0.0, 1.0)) = 0.2
        _AlphaFactor("Alpha Factor", Range(0.0, 1.0)) = 1.0
    }

    SubShader
    {
        // Tags{ "Queue"="Geometry" "RenderType"= "Transparent" "LightMode" = "ForwardBase" }
        Tags{ "Queue"="Transparent" "RenderType"= "Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        // ZWrite Off //謎

        CGINCLUDE
	    #include "UnityCG.cginc"

        fixed _Destruction, _ScaleFactor, _RotationFactor, _PositionFactor, _AlphaFactor;

        float rand(float3 co)
        {
            return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        }

        fixed3 rotate(fixed3 p, fixed3 rotation)
        {
            fixed3 a = normalize(rotation);
            fixed angle = length(rotation);
            if (abs(angle) < 0.001) return p;
            fixed s = sin(angle);
            fixed c = cos(angle);
            fixed r = 1.0 - c;
            fixed3x3 m = fixed3x3(
                a.x * a.x * r + c,
                a.y * a.x * r + a.z * s,
                a.z * a.x * r - a.y * s,
                a.x * a.y * r - a.z * s,
                a.y * a.y * r + c,
                a.z * a.y * r + a.x * s,
                a.x * a.z * r + a.y * s,
                a.y * a.z * r - a.x * s,
                a.z * a.z * r + c
            );
            return mul(m, p);
        }

        struct v2g
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 vertex : TEXCOORD1;
        };

        struct g2f
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            float light : TEXCOORD1;
        };

        v2g vert(appdata_full v)
        {
            v2g o;
            o.vertex = v.vertex;//ローカル座標
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;
            return o;
        }

        [maxvertexcount(3)]
        void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
        {
            g2f o;

            float3 center = (IN[0].vertex + IN[1].vertex + IN[2].vertex) / 3;
            fixed3 r3 = rand(center);
            float3 up = float3(0, 1, 0);

            // Compute the normal
            float3 vecA = IN[1].vertex - IN[0].vertex;
            float3 vecB = IN[2].vertex - IN[0].vertex;
            float3 normal = cross(vecA, vecB);
            normal = normalize(mul(normal, (float3x3) unity_WorldToObject));

            // Compute diffuse light
            float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
            o.light = max(0., dot(normal, lightDir));

            // Compute barycentric uv

            [unroll]
            for (int i = 0; i < 3; i++)
            {
                v2g v = IN[i];
                // g2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // center位置を起点にスケール変化
                v.vertex.xyz = (v.vertex.xyz - center) * (1.0 - _Destruction * _ScaleFactor) + center;

                // center位置を起点に、乱数を用いて回転を変化
                v.vertex.xyz = rotate(v.vertex.xyz - center, r3 * _Destruction * _RotationFactor) + center;

                // 法線方向に位置を変化
                v.vertex.xyz += normal * _Destruction * _PositionFactor * r3;

                // 修正した頂点位置を射影変換しレンダリング用に変換
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = IN[i].uv;
                triStream.Append(o);
            }

            triStream.RestartStrip();
        }


        ENDCG


        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            float4 _Color;
            sampler2D _MainTex;

            half4 frag(g2f i) : COLOR
            {
                float4 col = tex2D(_MainTex, i.uv);
                col.a *= 1.0 - _Destruction * _AlphaFactor;
                col.rgb *= i.light;
                return col;
            }
            ENDCG
        }

        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            half4 frag(g2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}