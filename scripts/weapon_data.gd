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
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.46, 0.2, 0.38), "origin": Vector3(0, 0.05, 0)},
                {"type": "prism", "size": Vector3(0.28, 0.18, 0.22), "origin": Vector3(0, -0.08, -0.05), "rotation_degrees": Vector3(0, 0, 12)},
                {"type": "cylinder", "height": 0.5, "top_radius": 0.07, "bottom_radius": 0.07, "segments": 16, "origin": Vector3(0, 0.05, 0.28), "rotation_degrees": Vector3(90, 0, 0)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.32, 0.18, 0.5), "origin": Vector3(0, 0.04, -0.08)},
                {"type": "cylinder", "height": 0.36, "top_radius": 0.08, "bottom_radius": 0.08, "segments": 16, "origin": Vector3(0, -0.02, 0.18), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "box", "size": Vector3(0.16, 0.22, 0.12), "origin": Vector3(-0.12, -0.1, -0.02)}
            ],
            "offset": Vector3(0.02, -0.04, -0.14),
            "scale": 0.55
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
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "prism", "size": Vector3(1.1, 0.28, 0.32)},
                {"type": "box", "size": Vector3(0.32, 0.16, 0.48), "origin": Vector3(-0.24, -0.1, -0.06), "rotation_degrees": Vector3(-10, 0, 0)},
                {"type": "cylinder", "height": 0.34, "top_radius": 0.09, "bottom_radius": 0.09, "segments": 14, "origin": Vector3(0.1, 0.12, 0.3), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "capsule", "radius": 0.08, "height": 0.5, "segments": 14, "origin": Vector3(0.24, 0.06, 0), "rotation_degrees": Vector3(0, 0, 90)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "prism", "size": Vector3(0.9, 0.26, 0.3)},
                {"type": "cylinder", "height": 0.28, "top_radius": 0.1, "bottom_radius": 0.1, "segments": 14, "origin": Vector3(0.08, 0.08, 0.24), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "box", "size": Vector3(0.22, 0.12, 0.22), "origin": Vector3(-0.18, -0.08, -0.02)},
                {"type": "capsule", "radius": 0.08, "height": 0.38, "segments": 14, "origin": Vector3(0.22, 0.02, -0.04), "rotation_degrees": Vector3(0, 90, 0)}
            ],
            "offset": Vector3(0.04, -0.02, -0.22),
            "scale": 0.46
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
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.82, 0.28, 0.36)},
                {"type": "cylinder", "height": 0.9, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 20, "origin": Vector3(0.16, 0.06, 0.18), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "cylinder", "height": 0.9, "top_radius": 0.12, "bottom_radius": 0.12, "segments": 20, "origin": Vector3(-0.16, 0.06, 0.18), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "prism", "size": Vector3(0.4, 0.22, 0.34), "origin": Vector3(0, -0.12, -0.08), "rotation_degrees": Vector3(-14, 0, 0)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "box", "size": Vector3(0.82, 0.22, 0.32)},
                {"type": "cylinder", "height": 0.72, "top_radius": 0.1, "bottom_radius": 0.12, "segments": 18, "origin": Vector3(0.16, 0.04, 0.18), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "cylinder", "height": 0.72, "top_radius": 0.1, "bottom_radius": 0.12, "segments": 18, "origin": Vector3(-0.16, 0.04, 0.18), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "prism", "size": Vector3(0.32, 0.18, 0.26), "origin": Vector3(0, -0.1, -0.06), "rotation_degrees": Vector3(-12, 0, 0)}
            ],
            "offset": Vector3(0.02, -0.06, -0.32),
            "scale": 0.5
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
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 1.05, "top_radius": 0.18, "bottom_radius": 0.26, "segments": 22},
                {"type": "cone", "height": 0.4, "top_radius": 0.04, "bottom_radius": 0.18, "segments": 18, "origin": Vector3(0, 0.6, 0)},
                {"type": "box", "size": Vector3(0.32, 0.1, 0.6), "origin": Vector3(0, -0.35, 0.04)},
                {"type": "box", "size": Vector3(0.42, 0.08, 0.4), "origin": Vector3(0, 0.1, -0.12)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 0.98, "top_radius": 0.18, "bottom_radius": 0.26, "segments": 22},
                {"type": "cone", "height": 0.28, "top_radius": 0.04, "bottom_radius": 0.18, "segments": 18, "origin": Vector3(0, 0.46, 0)},
                {"type": "box", "size": Vector3(0.3, 0.09, 0.48), "origin": Vector3(0, -0.28, 0.06)},
                {"type": "box", "size": Vector3(0.38, 0.08, 0.32), "origin": Vector3(0, 0.06, -0.12)}
            ],
            "offset": Vector3(0.02, -0.08, -0.42),
            "scale": 0.48
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
        "pickup_mesh": {
            "type": "composite",
            "parts": [
                {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.32, "ring_segments": 22, "rings": 14},
                {"type": "cylinder", "height": 0.45, "top_radius": 0.08, "bottom_radius": 0.08, "segments": 18, "origin": Vector3(0, 0.2, 0), "rotation_degrees": Vector3(90, 0, 0)},
                {"type": "capsule", "radius": 0.1, "height": 0.34, "segments": 14, "origin": Vector3(0, -0.18, 0)}
            ]
        },
        "weapon_model": {
            "type": "composite",
            "parts": [
                {"type": "cylinder", "height": 0.86, "top_radius": 0.08, "bottom_radius": 0.08, "segments": 18},
                {"type": "torus", "inner_radius": 0.08, "outer_radius": 0.18, "ring_segments": 22, "rings": 14, "origin": Vector3(0, 0.24, 0)},
                {"type": "torus", "inner_radius": 0.06, "outer_radius": 0.14, "ring_segments": 18, "rings": 12, "origin": Vector3(0, -0.18, 0)},
                {"type": "capsule", "radius": 0.1, "height": 0.24, "segments": 14, "origin": Vector3(0, -0.34, -0.02)}
            ],
            "offset": Vector3(0.0, -0.02, -0.24),
            "scale": 0.52
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
