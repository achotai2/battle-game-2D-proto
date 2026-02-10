shader_type canvas_item;

// --- RAIN SETTINGS ---
uniform float rain_amount : hint_range(0.0, 1.0) = 0.5; 
uniform float rain_speed : hint_range(0.0, 10.0) = 1.0;  
uniform float rain_slant : hint_range(-1.0, 1.0) = 0.2;  
uniform vec4 rain_color : source_color = vec4(0.8, 0.9, 1.0, 0.5); 

// --- CHAOS SETTINGS ---
// Assign a NoiseTexture2D here (FastNoiseLite)
uniform sampler2D noise_texture : repeat_enable; 
uniform float gust_speed : hint_range(0.0, 2.0) = 0.5; // How fast the "sheets" move
uniform float chaos_scale : hint_range(0.1, 5.0) = 1.0; // Size of the rain sheets

// --- FUNCTIONS ---
float rand(float n){
    return fract(sin(n) * 43758.5453123);
}

void fragment(){
    // 1. Time Setup
    float t = TIME * rain_speed;
    
    // 2. Sample the Chaos (Noise)
    // We scroll the noise texture sideways to simulate wind blowing sheets of rain.
    // We use a different time scale for the gusts so they don't lock to the drop speed.
    vec2 gust_uv = UV * chaos_scale;
    gust_uv.x += TIME * gust_speed; 
    gust_uv.y -= TIME * (gust_speed * 0.2); // Slight downward movement for gusts
    
    // Get the noise value (0.0 to 1.0)
    float storm_noise = texture(noise_texture, gust_uv).r;
    
    // Sharpen the noise to make distinct "bands" of rain
    // Smoothstep makes the darks darker and lights lighter
    storm_noise = smoothstep(0.3, 0.7, storm_noise);

    // 3. Coordinate Setup (Standard Rain)
    vec2 uv = UV;
    uv.x -= uv.y * rain_slant;
    vec2 grid_uv = uv * vec2(200.0, 40.0);
    grid_uv.y -= t; 
    
    // 4. Drop Logic
    float col_id = floor(grid_uv.x);
    // We offset the Y for randomness
    grid_uv.y += rand(col_id) * 50.0;
    
    float drop = fract(grid_uv.y); 
    // Sharpen into a trail
    float trail = pow(drop, 15.0);
    
    // 5. Apply Intensity & Chaos
    // We combine the static 'rain_amount' with our moving 'storm_noise'.
    // If storm_noise is low (0.0), this area gets NO rain.
    // If storm_noise is high (1.0), this area gets MAX rain.
    
    // We use a threshold check. 
    // The "Threshold" is dynamic based on our noise.
    float dynamic_threshold = 1.0 - (rain_amount * storm_noise);
    
    // Calculate visibility
    float show_rain = step(dynamic_threshold, rand(col_id * 12.345));
    
    // 6. Output
    vec4 final_color = rain_color;
    final_color.a *= trail * show_rain; 
    
    COLOR = final_color;
}