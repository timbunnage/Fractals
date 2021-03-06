Shader "Hidden/RayMarching"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Area("Area", vector) = (0, 0, 4, 4)
        _CamPosition("CamPosition", vector)  = (0, 1, 0)
        _CamRotation("CamRotation", vector) = (0, 0, 0)
        _LowFreq("LowFreq", vector) = (0, 0, 0, 0)
        _HighFreq("HighFreq", vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            // Ray Marching Variables
            #define MAX_STEPS 500       // No. steps a ray can take - see far side details of hollow structures
            #define MAX_DIST 1000.0     // Max distance of ray
            #define SURFACE_DIST 0.001  // Distance threshold for surface detection

            // Mandelbulb Variables
            #define ITERATIONS 100      // How detailed 
            #define BAILOUT 2
            #define POWER 8

            float4 _LowFreq;
            float4 _HighFreq;

            float2x2 Rotate(float a) {
                float s = sin(a);
                float c = cos(a);
                return float2x2(c, -s, s, c);
            }

            float DE(float3 pos, out float resColor) {
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;

                // orbit trap for colour
                float trap = length(z);

                for (int i = 0; i < ITERATIONS ; i++) {
                    r = length(z);
                    if (r>BAILOUT) break;
                    
                    // convert to polar coordinates
                    float theta = acos(z.z/r);
                    float phi = atan(z.y/z.x);
                    dr =  pow( r, POWER-1.0)*POWER*dr + 1.0;
                    
                    // scale and rotate the point
                    float zr = pow( r,POWER);
                    theta = theta*POWER;
                    phi = phi*POWER;
                    
                    // convert back to cartesian coordinates
                    // z = zr*float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));  // ORIGINAL
                    z = zr*float3(sin(theta)*cos(phi), clamp(sin(phi)*sin(theta), -1.0, 0.5*sin(4.3*_Time.y)+0.5), cos(theta));


                    z = zr*float3(sin(theta)*cos(phi), sin(phi)*sin(theta*sin(0.5*_Time.y)), cos(theta*sin(0.5*_Time.y)));
                    // z = zr*float3(clamp(sin(theta)*cos(phi), -1.0, 0.5*sin(4.3*_Time.y)+0.5), sin(phi)*sin(theta), cos(theta));
                    // z = zr*float3(sin(theta*sin(4.3*_Time.y))*cos(phi), clamp(sin(phi)*sin(theta), -1.0, 0.5*sin(4.3*_Time.y)+0.5), cos(theta));

                    // mandelbrot if power == 2
                    // z = zr*float3(cos(theta)*cos(phi), cos(theta)*sin(phi), sin(theta));

                    // z = zr*float3(sin(theta)*cos(phi), sin(phi)*sin(theta*sin(0.5*_Time.y)), cos(theta*sin(0.5*_Time.y)));



                    float piOverTwo = 1.57079632679;

                    z = zr*float3(
                        sin(theta + sin(_LowFreq.x * piOverTwo))*cos(phi + sin(_LowFreq.y * piOverTwo)), 
                        sin(phi + sin(_LowFreq.z * piOverTwo))*sin(theta + sin(_LowFreq.w * piOverTwo)), 
                        cos(theta + sin(_HighFreq.x * piOverTwo))
                    );

                    // z = zr*float3(
                    //     clamp(sin(theta), -1, 0.5*sin(_LowFreq.x)+0.5)  *  clamp(cos(phi), -1, 0.5*sin(_LowFreq.y)+0.5), 
                    //     clamp(sin(phi), -1, 0.5*sin(_LowFreq.z)+0.5) *  clamp(sin(theta), -1, 0.5*sin(_LowFreq.w)+0.5), 
                    //     clamp(cos(theta), -1, 0.5*sin(_HighFreq.x)+0.5)
                    // );

                    z+=pos;

                    trap = min(trap, length(z));
                }
                resColor = log(trap);
                
                return 0.5*log(r)*r/dr;
            }

            float GetDist(float3 p, out float resColor) {
                float4 sphere = float4(0, 1, 2.5, 1);
                float3 mandelbulb = p - float3(0, 1, 2.5);
                mandelbulb.xz = mul(mandelbulb.xz, Rotate(_Time.y));  // Rotate around y-axis

                float sphereDist = length(p - sphere.xyz) - sphere.w;
                float planeDist = p.y;

                float mandelbulbDist = DE(mandelbulb.xyz, resColor);

                float d = min(mandelbulbDist, planeDist);

                if (planeDist < mandelbulbDist) resColor = -1;

                return d;
            }


            float RayMarch(float3 ro, float3 rd, out float resColor) {
                float d0 = 0.0;
                for (int i = 0; i < MAX_STEPS; i++) {
                    float3 p = ro+d0*rd;
                    float dS = GetDist(p, resColor);  // distance to scene
                    d0 += dS;
                    if (dS<SURFACE_DIST || d0>MAX_DIST) break;
                }
                return d0;
            }

            float3 GetNormal(float3 p) {
                float tmp;
                float d = GetDist(p, tmp);
                float2 e = float2(0.001, 0.0);
                float3 n = d - float3(
                    GetDist(p-e.xyy, tmp),
                    GetDist(p-e.yxy, tmp),
                    GetDist(p-e.yyx, tmp));
                return normalize(n);
            }

            float GetLight(float3 p, float3 lightPos) {
                // float3 lightPos = float3(0.0, 8.0, 0.0);
                // lightPos.xz += float2(_SinTime.w, _CosTime.w) * 2.0;
                float3 l = normalize(lightPos - p);
                float3 n = GetNormal(p);

                float tmp;
                float dif = clamp(dot(n, l), 1.0, 1.0);  // angle between point and light
                float d = RayMarch(p+n*SURFACE_DIST*2.0, l, tmp); // ensure point doesn't start on object
                if (d<length(lightPos - p)) dif *= 0.7;  // add some base ambient light

                return dif;
            }

            // Color palette: https://www.iquilezles.org/www/articles/palettes/palettes.htm
            float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
                return a + b*cos(6.28318*(c*t+d) );     // 2pi
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 _Area;
            sampler2D _MainTex;
            float3 _CamPosition;
            float3 _CamRotation;


            fixed4 frag (v2f f) : SV_Target
            {
                float2 uv = _Area.xy + (f.uv - 0.5) * _Area.zw; 
                // float2 uv = f.uv * 2.0 - 1.0;

                // float3 camera_pos = float3(0.0, 1.0, 0.0);
                float3 camera_pos = _CamPosition.xyz; 

                float3 ro = camera_pos;
                float3 rd = float3(uv, 1.0); //kind of like fov
                // slightly high angle
                rd.y -= 0.18;
                ro.y += 0.3;
                // NOTE: Rotation order matters due to Gimbal lock
                // rd.yz = mul(rd.yz, Rotate(-_CamRotation.x)); // Mouse rotate around x
                // rd.xz = mul(rd.xz, Rotate(_CamRotation.y)); // Mouse rotate around y

                // ROTATE
                // float3 cosss = float3(uv.x, uv.y, 1.0)*_CosTime.w;
                // float3 kcrossuv = float3(1.0, 0.0, -uv.x)*_SinTime.w;
                // float3 third = float3(0.0, uv.y, 0.0) - float3(0.0, uv.y, 0.0)*_CosTime.w;
                // float3 rd = cosss + kcrossuv + third;
                
                // Raymarch to objects
                float resColor;
                float3 dist = RayMarch(ro, rd, resColor);
                float3 p = ro + rd * dist;
                
                // light sources
                float dif1 = GetLight(p, float3(0.0, 8.0, 0.0)); // diffuse light
                float dif2 = GetLight(p, float3(-3.0, 5.0, 1.0));
                float dif = 0.5*dif1 + 0.5*dif2;  // add lights together

                // far distances are reduced to 0
                float fog = 1.0 / (1.0 + dist * dist  * 0.005);


                // Add colours
                float mult = 1.3;

                // float3 col = float3(sin(dif*mult)*0.5 + 0.5, sin(dif*mult * 1.4)*0.5 + 0.5, sin(dif*mult* 0.8)*0.5 + 0.5);
                // float3 col = float3(dif, dif, dif);
                
                float3 col = palette(resColor*2 - 1, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),	float3(1.0, 1.0, 0.5), float3(0.80, 0.90, 0.30)) * fog *dif ;
                // float3 col = palette(resColor*2 - 1, float3(0.5,0.5,0.5),float3(0.5,0.5,0.5),float3(1.0,1.0,1.0),float3(0.0,0.33,0.67))*dif*dif*dif ;
                



                float3 sky = palette( uv.x*0.4 + uv.y*0.1 + 0.15*_Time.y, float3(0.5,1.0,1.0),float3(0.1,0.1,0.2),float3(1.0,1.0,1.0),float3(0.0,0.33,0.67));

                float3 ground = palette( uv.y*0.12  , float3(0.8,0.5,0.8),float3(0.8,0.4,0.8),float3(2.0,1.0,1.0),float3(0.0,0.25,0.25) );

                // base plane resColor is -1
                if (resColor == -1) col = ground  * fog * dif  +  sky * (1-fog) ;
                // if (resColor == -1) col = float3(113, 60, 76) / 256 * fog * dif  +  float3(0.8, 0.9, 1.0) * (1-fog) ;

                col*=0.8;

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
