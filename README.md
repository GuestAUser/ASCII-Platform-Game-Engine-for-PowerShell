# 🎮 ASCII Platform Game - PowerShell Edition
#### A fully-featured platform game with physics, collision detection, colors, and smooth gameplay

```ruby
     @                    o
    ═══               ═══════
              o                     X
         ═════════            ══════════
                        
══════════════════════════════════════════
```

## 📋 Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [How to Play](#how-to-play)
- [Controls](#controls)
- [Game Mechanics](#game-mechanics)
- [Levels](#levels)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)
- [Version History](#version-history)
- [License](#license)

## 🤖 Features

- **3 Challenging Levels** - Progressive difficulty from beginner to expert
- **Smooth 60 FPS Gameplay** - Optimized rendering for flicker-free experience
- **Full Color Support** - Vibrant colors for all game elements
- **Physics Engine** - Realistic gravity, jumping, and momentum
- **Enemy AI** - Patrolling enemies with defeat mechanics
- **Score System** - Points for coins and defeating enemies
- **Lives System** - 3 lives with invulnerability period after damage
- **Pause Functionality** - Pause mid-game to take a break

## 💻 Requirements

- **PowerShell 5.1** or higher
- **Windows Terminal** (recommended) or PowerShell Console
- Console window size: minimum 80x30 characters
- Administrator privileges NOT required

## 📥 Installation

1. **Download the game:**
   ```powershell
   # Clone or download game.ps1 to your local directory
   ```

2. **Enable script execution (if needed):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run the game:**
   ```powershell
   .\game.ps1
   ```

## 🎯 How to Play

### Objective
- Collect all coins (o) in each level to advance
- Avoid or defeat enemies (X) by jumping on them
- Complete all 3 levels to achieve victory!

### Game Elements

| Symbol | Element | Description |
|--------|---------|-------------|
| **@** | Player | You! Jump and move to victory |
| **o** | Coin | Collect all to complete level (+10 points) |
| **X** | Enemy | Avoid or jump on them (+50 points) |
| **═** | Platform | Stand and jump from these |
| **█** | Ground | Solid ground (green blocks) |

## 🎮 Controls

| Key | Action |
|-----|--------|
| **←** / **→** | Move left/right |
| **SPACE** / **↑** | Jump |
| **P** | Pause/Unpause game |
| **R** | Restart current level |
| **ESC** | Exit game |

## 🏃 Game Mechanics

### Movement
- **Smooth horizontal movement** with momentum
- **Variable jump height** - hold jump for higher jumps
- **Air control** - change direction mid-jump

### Combat
- **Jump on enemies** to defeat them and gain 50 points
- **Touching enemies** from the side costs you a life
- **2-second invulnerability** after taking damage (flashing effect)

### Physics
- **Gravity system** - realistic falling acceleration
- **Collision detection** - precise platform and enemy interactions
- **Momentum preservation** - slide slightly when stopping

## 🗺️ Levels

### Level 1 - Introduction
- Basic platform layout
- 2 enemies to practice combat
- 5 coins to collect
- Perfect for learning the controls

### Level 2 - Intermediate Challenge
- Gap jumps required
- More enemies (3)
- Random coin placement (8 coins)
- Moving platforms layout

### Level 3 - Expert Platforming
- Precise jumps required
- 4 fast-moving enemies
- Vertical climbing sections
- 7 strategically placed coins

## 🔧 Technical Details

### Architecture
- **Object-Oriented Design** - Full class hierarchy with inheritance
- **Game Engine** - 60 FPS frame-limited main loop
- **Render Pipeline** - Double-buffered color rendering
- **Physics System** - Vector-based movement with delta time

### Performance Optimizations
- Pre-allocated render buffers
- Batch color rendering
- Efficient collision detection
- Minimal garbage collection

### Code Structure
```
Vector2D          - 2D vector math
GameObject        - Base class for all entities
├── Player        - Player character with lives/score
├── Platform      - Static platforms
├── Coin          - Collectible items
└── Enemy         - AI-controlled enemies
GameEngine        - Main game loop and systems
```

## 🐛 Troubleshooting

### Game won't start
- Ensure you have PowerShell 5.1+: `$PSVersionTable.PSVersion`
- Check execution policy: `Get-ExecutionPolicy`
- Run PowerShell as your normal user (not as admin)

### Graphics issues
- Use Windows Terminal for best color support
- Ensure console is at least 80x30 characters
- Try maximizing the console window

### Performance problems
- Close other PowerShell tabs/windows
- Disable antivirus real-time scanning for the game folder
- Use Windows Terminal instead of legacy console

## 📝 Version History

- **v3.25.5** - Final optimized edition with flicker-free rendering
- **v3.0.0** - Added colors, pause, and invulnerability system
- **v2.0.0** - Improved physics and collision detection
- **v1.0.0** - Initial release

## 👤 Author

**GuestAUser**  

## 📄 License

This game is provided as-is for educational and entertainment purposes. Feel free to modify and share!

---

### 🎉 Enjoy the game!
