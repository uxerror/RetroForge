shader_type canvas_item;

// Pixelation
uniform int target_pixel_count : hint_range(8, 800) = 256;

// Color reduction
uniform int color_steps : hint_range(2, 32) = 8;

// Edge detection and sharpening
uniform float edge_strength : hint_range(0.0, 2.0) = 0.5;
uniform float sharpness : hint_range(0.0, 3.0) = 1.0;

// HSV adjustments
uniform float hue_shift : hint_range(-180.0, 180.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float value_brightness : hint_range(0.0, 2.0) = 1.0;

// Contrast and other adjustments
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float gamma : hint_range(0.1, 3.0) = 1.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;

// Outline
uniform float outline_thickness : hint_range(0.0, 20.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Dithering
uniform float dither_amount : hint_range(0.0, 1.0) = 0.5;
uniform float dither_blend : hint_range(0.0, 1.0) = 1.0;
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_sensitivity : hint_range(0.1, 2.0) = 1.0;
uniform float dot_size : hint_range(0.1, 2.0) = 1.0;
uniform vec4 dither_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Palette constraints
uniform bool use_palette = true;
uniform vec4 palette_color_1 : source_color = vec4(0.051, 0.169, 0.271, 1.0);  // #0d2b45
uniform vec4 palette_color_2 : source_color = vec4(0.125, 0.235, 0.337, 1.0);  // #203c56
uniform vec4 palette_color_3 : source_color = vec4(0.329, 0.306, 0.408, 1.0);  // #544e68
uniform vec4 palette_color_4 : source_color = vec4(0.553, 0.412, 0.478, 1.0);  // #8d697a
uniform vec4 palette_color_5 : source_color = vec4(0.816, 0.506, 0.349, 1.0);  // #d08159
uniform vec4 palette_color_6 : source_color = vec4(1.0, 0.667, 0.369, 1.0);    // #ffaa5e
uniform vec4 palette_color_7 : source_color = vec4(1.0, 0.831, 0.639, 1.0);    // #ffd4a3
uniform vec4 palette_color_8 : source_color = vec4(1.0, 0.925, 0.839, 1.0);    // #ffecd6

// Utility functions
vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 quantize_color(vec3 color) {
    float step_size = 1.0 / float(color_steps - 1);
    return floor(color / step_size) * step_size;
}

vec3 apply_palette(vec3 color) {
    if (!use_palette) return color;

    vec3 colors[8] = vec3[8](
        palette_color_1.rgb,
        palette_color_2.rgb,
        palette_color_3.rgb,
        palette_color_4.rgb,
        palette_color_5.rgb,
        palette_color_6.rgb,
        palette_color_7.rgb,
        palette_color_8.rgb
    );

    float min_dist = 10.0;
    vec3 closest_color = colors[0];

    for (int i = 0; i < 8; i++) {
        float dist = distance(color, colors[i]);
        if (dist < min_dist) {
            min_dist = dist;
            closest_color = colors[i];
        }
    }

    return closest_color;
}

vec3 detect_edges(sampler2D tex, vec2 uv, vec2 tex_size) {
    vec2 texel = 1.0 / tex_size;

    // Sobel edge detection
    vec3 tl = texture(tex, uv + vec2(-texel.x, -texel.y)).rgb;
    vec3 tc = texture(tex, uv + vec2(0.0, -texel.y)).rgb;
    vec3 tr = texture(tex, uv + vec2(texel.x, -texel.y)).rgb;
    vec3 ml = texture(tex, uv + vec2(-texel.x, 0.0)).rgb;
    vec3 mr = texture(tex, uv + vec2(texel.x, 0.0)).rgb;
    vec3 bl = texture(tex, uv + vec2(-texel.x, texel.y)).rgb;
    vec3 bc = texture(tex, uv + vec2(0.0, texel.y)).rgb;
    vec3 br = texture(tex, uv + vec2(texel.x, texel.y)).rgb;

    vec3 gx = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
    vec3 gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;

    return sqrt(gx * gx + gy * gy);
}

vec3 apply_sharpening(sampler2D tex, vec2 uv, vec2 tex_size) {
    vec2 texel = 1.0 / tex_size;
    vec3 center = texture(tex, uv).rgb;

    vec3 blur = (
        texture(tex, uv + vec2(-texel.x, -texel.y)).rgb +
        texture(tex, uv + vec2(0.0, -texel.y)).rgb +
        texture(tex, uv + vec2(texel.x, -texel.y)).rgb +
        texture(tex, uv + vec2(-texel.x, 0.0)).rgb +
        texture(tex, uv + vec2(texel.x, 0.0)).rgb +
        texture(tex, uv + vec2(-texel.x, texel.y)).rgb +
        texture(tex, uv + vec2(0.0, texel.y)).rgb +
        texture(tex, uv + vec2(texel.x, texel.y)).rgb
    ) / 8.0;

    return center + (center - blur) * sharpness;
}

float get_bayer_matrix(ivec2 pos) {
    // 4x4 Bayer matrix for dithering
    int bayer[16] = int[16](
        0,  8,  2,  10,
        12, 4,  14, 6,
        3,  11, 1,  9,
        15, 7,  13, 5
    );

    int x = pos.x % 4;
    int y = pos.y % 4;
    int index = y * 4 + x;

    return float(bayer[index]) / 15.0;
}

vec3 detect_shadow_transitions(sampler2D tex, vec2 uv, vec2 tex_size) {
    vec2 texel = 1.0 / tex_size;

    // Sample surrounding pixels
    vec3 center = texture(tex, uv).rgb;
    vec3 right = texture(tex, uv + vec2(texel.x, 0.0)).rgb;
    vec3 down = texture(tex, uv + vec2(0.0, texel.y)).rgb;
    vec3 left = texture(tex, uv + vec2(-texel.x, 0.0)).rgb;
    vec3 up = texture(tex, uv + vec2(0.0, -texel.y)).rgb;

    // Calculate luminance for each sample
    float lum_center = dot(center, vec3(0.299, 0.587, 0.114));
    float lum_right = dot(right, vec3(0.299, 0.587, 0.114));
    float lum_down = dot(down, vec3(0.299, 0.587, 0.114));
    float lum_left = dot(left, vec3(0.299, 0.587, 0.114));
    float lum_up = dot(up, vec3(0.299, 0.587, 0.114));

    // Calculate gradient magnitude (how much luminance changes)
    float grad_x = abs(lum_right - lum_left) * 0.5;
    float grad_y = abs(lum_down - lum_up) * 0.5;
    float gradient = sqrt(grad_x * grad_x + grad_y * grad_y);

    return vec3(gradient, lum_center, 0.0);
}

vec3 apply_dithering(vec3 color, vec2 screen_pos, sampler2D tex, vec2 uv, vec2 tex_size) {
    if (dither_amount <= 0.0) return color;

    // Detect shadow/light transitions
    vec3 transition_data = detect_shadow_transitions(tex, uv, tex_size);
    float gradient_strength = transition_data.x;
    float luminance = transition_data.y;

    // Only apply dithering in transition areas
    float transition_factor = smoothstep(0.05, 0.2, gradient_strength * shadow_sensitivity);
    if (transition_factor < 0.01) return color;

    // Get Bayer matrix value for current pixel
    ivec2 pixel_pos = ivec2(floor(screen_pos * dot_size));
    float bayer_value = get_bayer_matrix(pixel_pos);

    // Create threshold based on luminance and user control
    float threshold = dither_threshold + (bayer_value - 0.5) * dither_amount;

    // Determine if this pixel should be a dot
    float is_dot = step(threshold, luminance);

    // Create darker dots in shadow areas, lighter in bright areas
    vec3 dot_color = mix(dither_color.rgb, color * 1.2, luminance);
    vec3 dithered = mix(dot_color, color, is_dot);

    // Blend based on transition strength and user blend control
    float final_blend = transition_factor * dither_blend;
    return mix(color, dithered, final_blend);
}

void fragment() {
    vec2 texture_size = vec2(textureSize(TEXTURE, 0));

    // Apply pixelation
    vec2 pixel_uv = UV;

    if (target_pixel_count < int(texture_size.x)) {
        // Calculate how many source pixels map to one target pixel
        float scale_factor = texture_size.x / float(target_pixel_count);
        vec2 pixel_size = vec2(scale_factor) / texture_size;
        pixel_uv = floor(UV / pixel_size) * pixel_size + pixel_size * 0.5;
    }

    // Get base color
    vec4 tex_color = texture(TEXTURE, pixel_uv);
    vec3 color = tex_color.rgb;

    // Apply sharpening
    if (sharpness > 0.0) {
        color = apply_sharpening(TEXTURE, pixel_uv, texture_size);
    }

    // Apply HSV adjustments
    vec3 hsv = rgb_to_hsv(color);
    hsv.x = fract(hsv.x + hue_shift / 360.0);
    hsv.y *= saturation;
    hsv.z *= value_brightness;
    color = hsv_to_rgb(hsv);

    // Apply contrast and brightness
    color = pow(color, vec3(1.0 / gamma));
    color = (color - 0.5) * contrast + 0.5;
    color += brightness;

    // Apply palette constraint first (before quantization)
    color = apply_palette(color);

    // Quantize colors AFTER all other processing
    if (color_steps < 32) {
        color = quantize_color(color);
    }

    // Apply edge detection for outlines
    if (outline_thickness > 0.0) {
        vec3 edges = detect_edges(TEXTURE, pixel_uv, texture_size);
        float edge_strength_calc = length(edges);

        if (edge_strength_calc > edge_strength) {
            // Improved outline blending with better intensity scaling
            float outline_intensity = clamp(outline_thickness / 10.0, 0.0, 1.0);
            color = mix(color, outline_color.rgb, outline_intensity);
        }
    }

    // Apply dithering (after all other processing)
    // Use pixelated coordinates so dithering appears on the pixelated result
    vec2 screen_pos = pixel_uv * texture_size;
    color = apply_dithering(color, screen_pos, TEXTURE, pixel_uv, texture_size);

    // Clamp final color
    color = clamp(color, 0.0, 1.0);

    COLOR = vec4(color, tex_color.a);
}