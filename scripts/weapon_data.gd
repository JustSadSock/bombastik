extends Resource

const WEAPONS = [
    {
        "id": "pistol",
        "name": "Pistol",
        "damage": 15.0,
        "fire_rate": 3.0,
        "projectile_speed": 55.0,
        "spread": 0.01,
        "automatic": false,
        "projectile_scale": 0.2,
        "projectile_color": Color(1.0, 0.86, 0.56),
        "pickup_color": Color(1.0, 0.88, 0.54),
        "fire_style": "pistol",
        "fire_sound": {"freq": 540.0, "duration": 0.14, "amplitude": 0.65},
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.58, 0.26, 0.46), "origin": Vector3(0, 0.08, 0)},
                {"type": "prism", "size": Vector3(0.36, 0.22, 0.26), "origin": Vector3(0, -0.1, -0.08), "rotation_degrees": Vector3(0, 0, 12)},
                {"type": "cylinder", "height": 0.64, "top_radius": 0.08, "bottom_radius": 0.08, "segments": 18, "origin": Vector3(0, 0.05, 0.32), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "box", "size": Vector3(0.14, 0.12, 0.14), "origin": Vector3(0.18, 0.14, -0.12)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.48, 0.24, 0.76), "origin": Vector3(0, 0.06, -0.08)},
                {"type": "cylinder", "height": 0.52, "top_radius": 0.1, "bottom_radius": 0.12, "segments": 18, "origin": Vector3(0, 0.0, 0.32), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "box", "size": Vector3(0.2, 0.3, 0.18), "origin": Vector3(-0.16, -0.12, -0.02)},
                {"type": "prism", "size": Vector3(0.3, 0.16, 0.28), "origin": Vector3(0.14, 0.14, -0.24), "rotation_degrees": Vector3(0, 0, -18)},
                {"type": "torus", "inner_radius": 0.06, "outer_radius": 0.14, "ring_segments": 18, "rings": 12, "origin": Vector3(0.0, 0.08, 0.34)}
            ],
            "offset": Vector3(0.02, -0.04, -0.14),
            "scale": 0.95
        },
        "projectile_mesh": {
            "type": "composite",
            "parts": [
                {"type": "capsule", "radius": 0.1, "height": 0.32, "segments": 12},
                {"type": "cone", "height": 0.18, "top_radius": 0.0, "bottom_radius": 0.1, "segments": 12, "origin": Vector3(0, 0.25, 0)}
            ]
        },
    },
    {
        "id": "rifle",
        "name": "Pulse Rifle",
        "damage": 10.0,
        "fire_rate": 8.0,
        "projectile_speed": 75.0,
        "spread": 0.02,
        "automatic": true,
        "projectile_scale": 0.18,
        "projectile_color": Color(0.64, 0.92, 1.0),
        "pickup_color": Color(0.58, 0.86, 1.0),
        "fire_style": "burst",
        "fire_sound": {"freq": 460.0, "duration": 0.12, "amplitude": 0.6},
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "prism", "size": Vector3(1.28, 0.34, 0.42)},
                {"type": "box", "size": Vector3(0.4, 0.22, 0.58), "origin": Vector3(-0.28, -0.1, -0.06), "rotation_degrees": Vector3(-10, 0, 0)},
                {"type": "cylinder", "height": 0.44, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 16, "origin": Vector3(0.12, 0.14, 0.34), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "capsule", "radius": 0.1, "height": 0.62, "segments": 16, "origin": Vector3(0.28, 0.08, 0), "rotation_degrees": Vector3(0, 0, 90)},
                {"type": "box", "size": Vector3(0.32, 0.14, 0.26), "origin": Vector3(0.22, 0.16, -0.24)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "prism", "size": Vector3(1.26, 0.34, 0.46)},
                {"type": "cylinder", "height": 0.42, "top_radius": 0.14, "bottom_radius": 0.14, "segments": 18, "origin": Vector3(0.14, 0.14, 0.34), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "box", "size": Vector3(0.32, 0.18, 0.26), "origin": Vector3(-0.22, -0.12, -0.02)},
                {"type": "capsule", "radius": 0.12, "height": 0.56, "segments": 16, "origin": Vector3(0.32, 0.06, -0.04), "rotation_degrees": Vector3(0, 90, 0)},
                {"type": "torus", "inner_radius": 0.1, "outer_radius": 0.2, "ring_segments": 18, "rings": 12, "origin": Vector3(-0.08, 0.18, 0)},
                {"type": "box", "size": Vector3(0.22, 0.12, 0.24), "origin": Vector3(0.18, 0.22, -0.28)}
            ],
            "offset": Vector3(0.04, -0.02, -0.22),
            "scale": 0.92
        },
        "projectile_mesh": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 0.65, "top_radius": 0.06, "bottom_radius": 0.05, "segments": 18},
                {"type": "box", "size": Vector3(0.26, 0.02, 0.14), "origin": Vector3(0, 0.08, 0.02)},
                {"type": "box", "size": Vector3(0.26, 0.02, 0.14), "origin": Vector3(0, -0.08, 0.02)}
            ]
        },
    },
    {
        "id": "shotgun",
        "name": "Scattergun",
        "damage": 8.0,
        "fire_rate": 1.2,
        "projectile_speed": 50.0,
        "spread": 0.08,
        "pellets": 6,
        "automatic": false,
        "projectile_scale": 0.25,
        "projectile_color": Color(1.0, 0.7, 0.48),
        "pickup_color": Color(0.95, 0.64, 0.46),
        "fire_style": "kick",
        "fire_sound": {"freq": 310.0, "duration": 0.22, "amplitude": 0.72},
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.96, 0.32, 0.42)},
                {"type": "cylinder", "height": 1.1, "top_radius": 0.14, "bottom_radius": 0.14, "segments": 20, "origin": Vector3(0.18, 0.06, 0.2), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "cylinder", "height": 1.1, "top_radius": 0.14, "bottom_radius": 0.14, "segments": 20, "origin": Vector3(-0.18, 0.06, 0.2), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "prism", "size": Vector3(0.48, 0.26, 0.4), "origin": Vector3(0, -0.14, -0.1), "rotation_degrees": Vector3(-14, 0, 0)},
                {"type": "box", "size": Vector3(0.22, 0.12, 0.24), "origin": Vector3(0.3, 0.14, -0.2)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(1.1, 0.3, 0.42)},
                {"type": "cylinder", "height": 1.02, "top_radius": 0.14, "bottom_radius": 0.16, "segments": 20, "origin": Vector3(0.2, 0.06, 0.22), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "cylinder", "height": 1.02, "top_radius": 0.14, "bottom_radius": 0.16, "segments": 20, "origin": Vector3(-0.2, 0.06, 0.22), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "prism", "size": Vector3(0.44, 0.24, 0.34), "origin": Vector3(0, -0.14, -0.08), "rotation_degrees": Vector3(-12, 0, 0)},
                {"type": "box", "size": Vector3(0.24, 0.12, 0.24), "origin": Vector3(0.3, 0.1, -0.22)},
                {"type": "torus", "inner_radius": 0.1, "outer_radius": 0.18, "ring_segments": 18, "rings": 12, "origin": Vector3(-0.12, 0.16, 0)}
            ],
            "offset": Vector3(0.02, -0.06, -0.32),
            "scale": 0.96
        },
        "projectile_mesh": {
            "type": "composite",
            "parts": [
                {"type": "sphere", "radius": 0.11, "segments": 12, "rings": 10, "origin": Vector3(0.12, 0, 0)},
                {"type": "sphere", "radius": 0.11, "segments": 12, "rings": 10, "origin": Vector3(-0.12, 0, 0)},
                {"type": "sphere", "radius": 0.1, "segments": 12, "rings": 10, "origin": Vector3(0, 0.1, 0)}
            ]
        },
    },
    {
        "id": "rocket",
        "name": "Rocket Launcher",
        "damage": 40.0,
        "fire_rate": 0.8,
        "projectile_speed": 35.0,
        "spread": 0.03,
        "automatic": false,
        "projectile_scale": 0.3,
        "explosive": true,
        "projectile_color": Color(1.0, 0.46, 0.34),
        "pickup_color": Color(1.0, 0.54, 0.32),
        "fire_style": "heavy",
        "fire_sound": {"freq": 220.0, "duration": 0.26, "amplitude": 0.78},
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 1.28, "top_radius": 0.22, "bottom_radius": 0.3, "segments": 24},
                {"type": "cone", "height": 0.48, "top_radius": 0.05, "bottom_radius": 0.22, "segments": 20, "origin": Vector3(0, 0.74, 0)},
                {"type": "box", "size": Vector3(0.38, 0.14, 0.72), "origin": Vector3(0, -0.36, 0.06)},
                {"type": "box", "size": Vector3(0.52, 0.12, 0.46), "origin": Vector3(0, 0.14, -0.12)},
                {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.24, "ring_segments": 20, "rings": 12, "origin": Vector3(0, 0.22, 0)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 1.36, "top_radius": 0.24, "bottom_radius": 0.32, "segments": 24},
                {"type": "cone", "height": 0.42, "top_radius": 0.06, "bottom_radius": 0.22, "segments": 20, "origin": Vector3(0, 0.62, 0)},
                {"type": "box", "size": Vector3(0.36, 0.12, 0.64), "origin": Vector3(0, -0.36, 0.08)},
                {"type": "box", "size": Vector3(0.52, 0.1, 0.42), "origin": Vector3(0, 0.12, -0.16)},
                {"type": "torus", "inner_radius": 0.16, "outer_radius": 0.26, "ring_segments": 20, "rings": 12, "origin": Vector3(0, -0.1, 0)},
                {"type": "capsule", "radius": 0.16, "height": 0.32, "segments": 16, "origin": Vector3(0.0, -0.46, 0.0)}
            ],
            "offset": Vector3(0.02, -0.08, -0.42),
            "scale": 1.05
        },
        "projectile_mesh": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 0.55, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 18},
                {"type": "cone", "height": 0.24, "top_radius": 0.02, "bottom_radius": 0.12, "segments": 18, "origin": Vector3(0, 0.34, 0)},
                {"type": "box", "size": Vector3(0.3, 0.04, 0.14), "origin": Vector3(0, -0.18, 0.08)},
                {"type": "box", "size": Vector3(0.3, 0.04, 0.14), "origin": Vector3(0, -0.18, -0.08)}
            ]
        },
    },
    {
        "id": "laser",
        "name": "Laser Beam",
        "damage": 6.0,
        "fire_rate": 14.0,
        "projectile_speed": 120.0,
        "spread": 0.0,
        "automatic": true,
        "projectile_scale": 0.12,
        "projectile_color": Color(0.64, 1.0, 0.7),
        "pickup_color": Color(0.5, 1.0, 0.72),
        "fire_style": "beam",
        "fire_sound": {"freq": 640.0, "duration": 0.12, "amplitude": 0.58},
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "torus", "inner_radius": 0.16, "outer_radius": 0.38, "ring_segments": 24, "rings": 16},
                {"type": "cylinder", "height": 0.56, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 20, "origin": Vector3(0, 0.22, 0), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "capsule", "radius": 0.14, "height": 0.42, "segments": 16, "origin": Vector3(0, -0.22, 0)},
                {"type": "box", "size": Vector3(0.24, 0.14, 0.28), "origin": Vector3(0.16, 0.16, -0.18)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 1.26, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 20},
                {"type": "torus", "inner_radius": 0.1, "outer_radius": 0.24, "ring_segments": 22, "rings": 16, "origin": Vector3(0, 0.32, 0)},
                {"type": "torus", "inner_radius": 0.08, "outer_radius": 0.2, "ring_segments": 18, "rings": 14, "origin": Vector3(0, -0.24, 0)},
                {"type": "capsule", "radius": 0.14, "height": 0.36, "segments": 16, "origin": Vector3(0, -0.46, -0.02)},
                {"type": "box", "size": Vector3(0.28, 0.14, 0.36), "origin": Vector3(0, 0.14, -0.22)},
                {"type": "prism", "size": Vector3(0.26, 0.14, 0.28), "origin": Vector3(0.14, 0.22, 0.0), "rotation_degrees": Vector3(0, 0, 16)}
            ],
            "offset": Vector3(0.0, -0.02, -0.24),
            "scale": 1.0
        },
        "projectile_mesh": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 1.1, "top_radius": 0.06, "bottom_radius": 0.06, "segments": 18},
                {"type": "torus", "inner_radius": 0.05, "outer_radius": 0.12, "ring_segments": 18, "rings": 12, "origin": Vector3(0, 0.28, 0)},
                {"type": "torus", "inner_radius": 0.05, "outer_radius": 0.12, "ring_segments": 18, "rings": 12, "origin": Vector3(0, -0.28, 0)}
            ]
        },
    }
]
