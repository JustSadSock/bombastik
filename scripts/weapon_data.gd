extends Resource

const WEAPONS = [
    {"id": "pistol", "name": "Pistol", "damage": 15.0, "fire_rate": 3.0, "projectile_speed": 55.0, "spread": 0.01, "automatic": false, "projectile_scale": 0.2},
    {"id": "rifle", "name": "Pulse Rifle", "damage": 10.0, "fire_rate": 8.0, "projectile_speed": 75.0, "spread": 0.02, "automatic": true, "projectile_scale": 0.18},
    {"id": "shotgun", "name": "Scattergun", "damage": 8.0, "fire_rate": 1.2, "projectile_speed": 50.0, "spread": 0.08, "pellets": 6, "automatic": false, "projectile_scale": 0.25},
    {"id": "rocket", "name": "Rocket Launcher", "damage": 40.0, "fire_rate": 0.8, "projectile_speed": 35.0, "spread": 0.03, "automatic": false, "projectile_scale": 0.3, "explosive": true},
    {"id": "laser", "name": "Laser Beam", "damage": 6.0, "fire_rate": 14.0, "projectile_speed": 120.0, "spread": 0.0, "automatic": true, "projectile_scale": 0.12}
]
