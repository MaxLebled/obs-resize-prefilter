float3 tap(float2 uv)
{
    float3 c = image.Sample(textureSampler, uv).rgb; // Sample...
    return pow(c, 2.2); // ... and linearise using 2.2 gamma. not sRGB but close enough
}

float4 mainImage(VertData v_in) : TARGET // OBS entry point
{
    float2 px = uv_pixel_interval;
    float2 uv = v_in.uv;
    float dx1 = px.x;
    float dx2 = 2.0 * px.x;
    float dy1 = px.y;
    float dy2 = 2.0 * px.y;

	// OBS is going to average pixels in pairs and I can't stop it. So instead,
	// I make it so that after OBS averages it, I land on the right answer
	
    // Catmull-Rom curve, note the negative lobes.
	// -3   -9   29   111   111   29   -9   -3      ->     adds up to 256
	// This is the destination I'm trying to get to.
	
	// But OBS has the unavoidable box filter that does this:
	//                128   128
	// so my kernel will be different to PRE-COMPENSATE for it

	//       -6         -12        70         152        70         -12        -6      <-- effective kernel with OBS box accounted for
	//      /   \      /   \      /   \      /   \      /   \      /   \      /   \
	//   -3     -3  -6     -6  35     35  76     76  35     35  -6     -6  -3     -3   <-- box filter halves each one and sends it both ways
	//    /      \   /      \   /      \   /      \   /      \   /      \   /      \       
	// -3         -9         29         111        111        29         -9        -3  <-- this is what I want OBS to produce
	
	// now we will simplify this further to be a 5-tap filter
	// rather than a 7-tap filter for my sanity
	
    // 7-TAP    -6   -12    70   152    70   -12    -6      
    // 5-TAP         -20    76   144    76   -20      
	//                wc    wb    wa    wb    wc

	// and now down here I am putting the fractions
	
    float wa =  0.562500;   // offset 0,          144/256
    float wb =  0.296875;   // offset 1px away,   76/256
    float wc = -0.078125;   // offset 2px away,  -20/256

	// Now I am reading my 5 pixels (taps) left to right and applying those weights, row by row

    // ROW TWO PIXELS ABOVE CENTRE
    float3 r0 = wc * tap(uv + float2(-dx2, -dy2)) + wb * tap(uv + float2(-dx1, -dy2))
              + wa * tap(uv + float2( 0.0, -dy2)) + wb * tap(uv + float2( dx1, -dy2))
              + wc * tap(uv + float2( dx2, -dy2));

    // ROW ONE PIXEL ABOVE CENTRE
    float3 r1 = wc * tap(uv + float2(-dx2, -dy1)) + wb * tap(uv + float2(-dx1, -dy1))
              + wa * tap(uv + float2( 0.0, -dy1)) + wb * tap(uv + float2( dx1, -dy1))
              + wc * tap(uv + float2( dx2, -dy1));

    // CENTRE ROW.
    float3 r2 = wc * tap(uv + float2(-dx2, 0.0)) + wb * tap(uv + float2(-dx1, 0.0))
              + wa * tap(uv)                     + wb * tap(uv + float2( dx1, 0.0))
              + wc * tap(uv + float2( dx2, 0.0));

    // ROW ONE PIXEL BELOW CENTRE.
    float3 r3 = wc * tap(uv + float2(-dx2, dy1)) + wb * tap(uv + float2(-dx1, dy1))
              + wa * tap(uv + float2( 0.0, dy1)) + wb * tap(uv + float2( dx1, dy1))
              + wc * tap(uv + float2( dx2, dy1));

    // ROW TWO PIXELS BELOW CENTRE.
    float3 r4 = wc * tap(uv + float2(-dx2, dy2)) + wb * tap(uv + float2(-dx1, dy2))
              + wa * tap(uv + float2( 0.0, dy2)) + wb * tap(uv + float2( dx1, dy2))
              + wc * tap(uv + float2( dx2, dy2));

    // Now I have my 5 "final" horizontal pixels and I must collapse them vertically
    float3 kernelresult = wc * r0 + wb * r1 + wa * r2 + wb * r3 + wc * r4;

    // Clamp minimum pixel value to zero otherwise it could become a NaN
    kernelresult = max(kernelresult, 0.0); // the "max" operation means "the larger of these 2 values"

    // Un-linearise, we're going back to gamma space
    kernelresult = pow(kernelresult, 1.0 / 2.2);

    // Pass alpha through unchanged (it'll still get the unavoidable box filter)
    float4 src = image.Sample(textureSampler, uv);

    // Finally clamp the whole image to 0-1 using "saturate" because
	// the negative lobes can theoretically output numbers above 1
    return float4(saturate(kernelresult), src.a);
}
