# Northward Uprising

**Game Design Document**
- **Version:** 1.0.0
- **Status:** Pre-Production / Architecture
- **Target Platform:** PC (Windows/Linux/Mac)
- **Engine:** Godot 4.5.1 (GDScript)
- **Genre:** 2D Turn-Based Tactical RPG
- **Visual Style:** 32-bit Top-Down Pixel Art (High Fantasy / Gritty)

---

## 1. Executive Summary
Northward Uprising is a tactical RPG about the cost of revolution. Players command Aric, a gladiator turned rebel leader, managing a guerilla army across the frozen Northern Kingdoms. 

Unlike traditional SRPGs where players rely on a single "hero squad," Northward Uprising forces the player to manage physical exhaustion. The **Stamina System** necessitates unit rotation, simulating the logistical nightmare of a prolonged war. The narrative is linear, high-stakes, and focuses on the "human resource" cost of freedom.

### 1.1 Unique Selling Points (USP)
*   **The Fatigue Economy:** Units get tired. A "tired" army is a dead army. Players must rotate their roster, giving the B-Team crucial screentime.
*   **The "Wounded" State:** Permadeath is not always instant, but it is always looming. The "Downed -> Wounded -> Dead" pipeline creates moments of desperate rescue.
*   **Narrative-First Tactics:** No grinding. Resources are finite. The story drives the mechanics; hunger and cold are just as deadly as enemy swords.

---

## 2. Gameplay Mechanics

### 2.1 The Turn Structure (Phase Based)
The game follows a strict **Player Phase / Enemy Phase (PP/EP)** structure.
*   **Start of PP:** All non-fatigued, non-downed Player Units refresh.
*   **Player Actions:** Move, Attack, Item, Rescue, Wait.
*   **End of PP:** Turn Counter increments. Passive Healing applies.
*   **Start of EP:** Enemy AI calculates threat ranges.
*   **Enemy Actions:** AI prioritizes lethal damage -> lowest defense -> closest target.
*   **End of EP:** Status effects (Poison/Bleed) tick damage.

### 2.2 The Grid & Movement
*   **Grid Size:** 16x16 pixels base (Managed via `TileMapLayer` and `Globals.CELL_SIZE`).
*   **Pathfinding:** A* Algorithm (Manhattan Distance, implemented in `world.gd` using `AStar2D`).
*   **Terrain Costs:**
    *   **Plains:** Cost 1 | Def +0 | Avo +0
    *   **Forest:** Cost 2 | Def +1 | Avo +20%
    *   **Mountain:** Cost 3 (Infantry only) | Def +3 | Avo +30%
    *   **Fort:** Cost 2 | Def +2 | Avo +20% | Heal 10% HP start of turn.

### 2.3 The "Downed" & "Rescue" System (Core Pillar)
This system replaces standard HP=0 Death.

**Phase 1: DOWNED**
*   **Trigger:** Unit HP reaches 0.
*   **State Changes:** 
    *   Unit Sprite: Kneeling.
    *   Unit Collision: Disabled (Enemies can walk through).
*   **Actions:** None (Cannot Move, Act, Dodge, or Block).
*   **Bleed Out Timer:** Starts at 5 Turns. Decrements at the start of Player Phase.
*   **AI Behavior:** Enemy AI ignores Downed units unless they are the only valid target remaining on the map.

**Phase 2: RESCUE**
*   **Action:** An adjacent Ally uses the Rescue command.
*   **Result:** The Downed unit is removed from the map (Retreat). They survive the chapter but receive the Fatigue Penalty (0 Stamina).

**Phase 3: WOUNDED (The Risk)**
*   **Trigger:** If a unit was Downed and subsequently Revived (via rare Item/Magic) during the battle.
*   **Status:** The unit acts normally but carries the **Wounded** tag.
*   **Permadeath Condition:** If a Wounded unit reaches 0 HP -> **Instant Permadeath**.

### 2.4 Stamina & Fatigue System
Designed to force roster rotation over a 30-chapter campaign.
*   **Max Stamina:** 100
*   **Deployment Cost:** -20 Stamina per chapter.
*   **Rest Recovery:** +100 Stamina (Full Restore) if the unit is NOT deployed for one chapter.
*   **Thresholds:**
    *   **Fresh (21-100):** Normal stats.
    *   **Fatigued (0-20):** Cannot Deploy.
    *   **Exception:** *Desperation Deployment.* If the player has fewer than the minimum required units, they may deploy a Fatigued unit.
    *   **Penalty:** Max HP -50%, Strength -50%. 0 XP Gain.

---

## 3. Combat Logic & Math

### 3.1 The Elemental Trinity
A combined physical/magical affinity system.
*   **Triangle:** Fire (Sword) > Wind (Axe) > Thunder (Lance) > Fire (Sword).
*   **Advantage:** +20% Dmg, +15% Hit.
*   **Disadvantage:** -20% Dmg, -15% Hit.
*   **Neutral:** Light/Dark Magic, Bows (unless specified).

### 3.2 Combat Formulas
*   **Hit Rate:** `(Finesse * 2 + Luck / 2 + WeaponHit) - (EnemyAgility * 2 + EnemyLuck + TerrainAvo)`
*   **Attack Speed (AS):** `Agility - (WeaponWeight - Might / 5)` (Clamped at 0 min).
*   **Doubling:** If `Attacker AS >= Defender AS + 4`, Attacker strikes twice.
*   **Physical Damage:** `((Might + WeaponMt) - (EnemyFortitude + TerrainDef)) * ElementMod`
*   **Magical Damage:** `((Arcana + SpellMt) - (EnemyWillpower + TerrainRes)) * ElementMod`
*   **Critical Rate:** `((Finesse / 2) + WeaponCrit) - (EnemyLuck + EnemyWillpower / 2)`
*   **Crit Dmg:** 3x Final Damage.

---

## 4. Characters & Progression

### 4.1 Stats (Thematic Naming)
| Stat | Traditional Name | Effect |
| :--- | :--- | :--- |
| **Vigor** | HP | Life Points. |
| **Might** | STR | Physical damage calculation. |
| **Arcana** | MAG | Magic damage & Healing potency. |
| **Finesse** | SKL | Hit Rate & Critical Rate. |
| **Agility** | SPD | Avoidance & Doubling threshold. |
| **Fortitude** | DEF | Physical Damage reduction. |
| **Willpower** | RES | Magic Damage reduction. |
| **Luck** | LCK | Minor boost to Hit/Avo/CritAvo. |

### 4.2 Growth & Classes
*   **Soft Class System:** Classes dictate Equipment Access (e.g., Gladiator = Sword/Axe) and Base Stats.
*   **Growth:** Fixed probability rolls on Level Up.
*   **RNG Mode:** "Hybrid" (If a unit fails to level a stat 3 times in a row, the 4th time is guaranteed to prevent 'stat screw').

---

## 5. Narrative & Scope

### 5.1 Structure
*   **Total Scope:** 30 Chapters.
*   **Pacing:** Linear. No World Map backtracking.
*   **Interludes:** "Camp Phase" between chapters. Menu-based.
    *   Manage Inventory.
    *   Talk (Support Conversations).
    *   Select Units (Stamina Management).

### 5.2 Delivery
*   **Intro/Outro:** Text scroll + Pixel Art Vignette.
*   **In-Map Dialogue:** "Battle Barks" (Short lines when engaging specific enemies) and Event Tiles (Aric steps on specific tile -> Dialogue triggers).
*   **Camp:** Visual Novel style (Portrait + Text Box).

---

## 6. Technical Architecture (Godot)

### 6.1 File Structure
**Note:** Updated to match current repository structure.

```text
res://
├── Assets/ (Sprites, Audio, Fonts, Tilesets)
├── Resources/
│   ├── EnemyUnits/ (e.g., test_enemy_unit.tres)
│   ├── PlayerUnits/ (e.g., test_player_unit.tres)
│   ├── enemy_resource.gd (Inherits UnitResource)
│   └── unit_resource.gd (Base Data Class)
├── Scenes/
│   ├── test.tscn (Current test map)
│   ├── actor.tscn (Base entity scene)
│   ├── highlights.tscn
│   └── UI/ (GridCursor, MouseCursor)
├── Scripts/
│   ├── Globals/ (globals.gd, game_manager.gd, combat_manager.gd, etc.)
│   ├── Utility/ (arrays.gd, math.gd, vectors.gd, etc.)
│   ├── world.gd (Map Logic & A*)
│   ├── actor.gd (Base class)
│   ├── actor_player.gd
│   └── actor_enemy.gd
└── UI/ (gui.tscn, unit_combat_options.tscn, etc.)
```

### 6.2 Data Persistence
*   **Runtime:** `UnitResource` stores current data in memory.
*   **Save/Load:** `save_manager.gd` (located in `Scripts/Globals/`) will serialize all `UnitResource` objects into a dictionary and save to `user://savegame.json`.
*   **Keys:** `UnitID`, `CurrentHP`, `CurrentXP`, `InventoryIndices`, `FatigueLevel`, `IsDead`.
