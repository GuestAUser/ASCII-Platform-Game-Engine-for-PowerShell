#Requires -Version 5.1
<#
.SYNOPSIS
    ASCII Platform Game Engine for PowerShell
.DESCRIPTION
    A fully-featured platform game with physics, collision detection, colors, and smooth gameplay
.AUTHOR
    GuestAUser
.VERSION
    3.25.5 - Final Optimized Edition
#>

using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text
using namespace System.Threading

# Region: Core Game Classes

class Vector2D {
    [double]$X
    [double]$Y
    
    Vector2D([double]$x, [double]$y) {
        $this.X = $x
        $this.Y = $y
    }
    
    [Vector2D] Add([Vector2D]$other) {
        return [Vector2D]::new($this.X + $other.X, $this.Y + $other.Y)
    }
    
    [Vector2D] Multiply([double]$scalar) {
        return [Vector2D]::new($this.X * $scalar, $this.Y * $scalar)
    }
}

class GameObject {
    [Vector2D]$Position
    [Vector2D]$Velocity
    [char]$Symbol
    [ConsoleColor]$Color
    [bool]$IsSolid
    [string]$Type
    [bool]$MarkedForRemoval = $false
    
    GameObject([double]$x, [double]$y, [char]$symbol, [ConsoleColor]$color, [bool]$solid, [string]$type) {
        $this.Position = [Vector2D]::new($x, $y)
        $this.Velocity = [Vector2D]::new(0, 0)
        $this.Symbol = $symbol
        $this.Color = $color
        $this.IsSolid = $solid
        $this.Type = $type
    }
    
    [void] Update([double]$deltaTime) {
        $this.Position = $this.Position.Add($this.Velocity.Multiply($deltaTime))
    }
}

class Player : GameObject {
    hidden [double]$JumpPower = 28.0
    hidden [double]$MoveSpeed = 38.5
    hidden [double]$InvulnerableTime = 0.0
    [bool]$IsGrounded = $false
    [int]$Lives = 3
    [int]$Score = 0
    [bool]$IsInvulnerable = $false
    
    Player([double]$x, [double]$y) : base($x, $y, '@', [ConsoleColor]::Cyan, $true, 'Player') {}
    
    [void] Jump() {
        if ($this.IsGrounded) {
            $this.Velocity.Y = -$this.JumpPower
            $this.IsGrounded = $false
        }
    }
    
    [void] Move([double]$direction) {
        $this.Velocity.X = $direction * $this.MoveSpeed
    }
    
    [void] Update([double]$deltaTime) {
        ([GameObject]$this).Update($deltaTime)
        
        # Update < invulnerability >;
        if ($this.IsInvulnerable) {
            $this.InvulnerableTime -= $deltaTime
            if ($this.InvulnerableTime -le 0) {
                $this.IsInvulnerable = $false
                $this.Color = [ConsoleColor]::Cyan
            }
            else {
                $this.Color = if ([int]($this.InvulnerableTime * 10) % 2) { [ConsoleColor]::Cyan } else { [ConsoleColor]::White }
            }
        }
    }
    
    [void] TakeDamage() {
        if (-not $this.IsInvulnerable) {
            $this.Lives--
            $this.IsInvulnerable = $true
            $this.InvulnerableTime = 2.0
        }
    }
}

class Platform : GameObject {
    [int]$Width
    
    Platform([double]$x, [double]$y, [int]$width) : base($x, $y, '=', [ConsoleColor]::DarkGray, $true, 'Platform') {
        $this.Width = $width
    }
}

class Coin : GameObject {
    hidden [double]$AnimationTime = 0.0
    [int]$Value = 10
    [bool]$Collected = $false
    
    Coin([double]$x, [double]$y) : base($x, $y, 'o', [ConsoleColor]::Yellow, $false, 'Coin') {}
    
    [void] Update([double]$deltaTime) {
        $this.AnimationTime += $deltaTime * 3
        $this.Color = if ([Math]::Sin($this.AnimationTime) -gt 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkYellow }
    }
}

class Enemy : GameObject {
    hidden [double]$PatrolSpeed = 10.0
    hidden [double]$PatrolLeft
    hidden [double]$PatrolRight
    hidden [bool]$MovingRight = $true
    [bool]$IsDead = $false
    
    Enemy([double]$x, [double]$y, [double]$patrolRange) : base($x, $y, 'X', [ConsoleColor]::Red, $true, 'Enemy') {
        $this.PatrolLeft = $x - $patrolRange
        $this.PatrolRight = $x + $patrolRange
        $this.Velocity.X = $this.PatrolSpeed
    }
    
    [void] Update([double]$deltaTime) {
        if (-not $this.IsDead) {
            ([GameObject]$this).Update($deltaTime)
            
            if (($this.Position.X -le $this.PatrolLeft -and -not $this.MovingRight) -or
                ($this.Position.X -ge $this.PatrolRight -and $this.MovingRight)) {
                $this.MovingRight = -not $this.MovingRight
                $this.Velocity.X = if ($this.MovingRight) { $this.PatrolSpeed } else { -$this.PatrolSpeed }
            }
        }
    }
    
    [void] Die() {
        $this.IsDead = $true
        $this.Symbol = '-'
        $this.Color = [ConsoleColor]::DarkRed
        $this.Velocity.X = 0
        $this.IsSolid = $false
    }
}

class GameEngine {
    hidden [int]$Width = 80
    hidden [int]$Height = 24
    hidden [double]$Gravity = 65.0
    hidden [List[GameObject]]$GameObjects
    hidden [System.Diagnostics.Stopwatch]$Stopwatch
    hidden [double]$LastFrameTime = 0
    hidden [hashtable]$KeyStates = @{ Left = $false; Right = $false }
    hidden [bool]$EndScreenDrawn = $false
    hidden [StringBuilder]$RenderBuffer
    hidden [ConsoleColor[][]]$ColorBuffer
    hidden [char[][]]$CharBuffer
    hidden [double]$GameStartTime = 0.0
    hidden [double]$TotalElapsedTime = 0.0
    hidden [double]$TotalTargetTime = 75.0  # 20 + 40 + 15 seconds; 
    hidden [bool]$TimerStarted = $false
    
    [Player]$Player
    [bool]$Running = $true
    [int]$Level = 1
    [bool]$GamePaused = $false
    [string]$GameState = 'Playing'  # Playing, GameOver, Victory;
    
    GameEngine() {
        $this.GameObjects = [List[GameObject]]::new()
        $this.Stopwatch = [System.Diagnostics.Stopwatch]::new()
        $this.RenderBuffer = [StringBuilder]::new(2000)
        $this.CharBuffer = New-Object 'char[][]' $this.Height
        $this.ColorBuffer = New-Object 'ConsoleColor[][]' $this.Height
        
        # Pre-allocate [ arrays ];
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.CharBuffer[$y] = New-Object 'char[]' $this.Width
            $this.ColorBuffer[$y] = New-Object 'ConsoleColor[]' $this.Width
        }
        
        $this.InitializeLevel()
    }
    
    [void] InitializeLevel() {
        $this.GameObjects.Clear()
        $this.GameState = 'Playing'
        $this.EndScreenDrawn = $false
        
        #timer-init < first-level-only >;
        if ($this.Level -eq 1 -and -not $this.TimerStarted) {
            $this.GameStartTime = $this.Stopwatch.Elapsed.TotalSeconds
            $this.TotalElapsedTime = 0.0
            $this.TimerStarted = $true
        }
        
        #player;
        $this.Player = [Player]::new(5, 18)
        $this.GameObjects.Add($this.Player)
        
        #level;
        switch ($this.Level) {
            1 { $this.CreateLevel1() }
            2 { $this.CreateLevel2() }
            3 { $this.CreateLevel3() }
            default { $this.CreateLevel1() }
        }
    }
    
    [void] CreateLevel1() {
        #ground;
        $ground = [Platform]::new(0, 22, 80)
        $ground.Color = [ConsoleColor]::Green
        $ground.Symbol = [char]0x2588
        $this.GameObjects.Add($ground)
        
        #platforms;
        @(
            @(10, 18, 15),
            @(30, 14, 12),
            @(50, 16, 20),
            @(15, 10, 10),
            @(40, 8, 15)
        ) | ForEach-Object { $this.GameObjects.Add([Platform]::new($_[0], $_[1], $_[2])) }
        
        #coins;
        @(
            @(15, 17), @(35, 13), @(60, 15), @(20, 9), @(45, 7)
        ) | ForEach-Object { $this.GameObjects.Add([Coin]::new($_[0], $_[1])) }
        
        #enemies;
        $this.GameObjects.Add([Enemy]::new(35, 21, 5))
        $this.GameObjects.Add([Enemy]::new(55, 15, 4))
    }
    
    [void] CreateLevel2() {
        #Ground-platforms;
        @(
            @(0, 22, 20), @(25, 22, 55)
        ) | ForEach-Object { 
            $p = [Platform]::new($_[0], $_[1], $_[2])
            $p.Color = [ConsoleColor]::Green
            $p.Symbol = [char]0x2588
            $this.GameObjects.Add($p)
        }
        
        #Air-platforms;
        @(
            @(5, 18, 8), @(18, 15, 10), @(32, 17, 8),
            @(45, 14, 12), @(62, 16, 10), @(25, 10, 15), @(50, 8, 10)
        ) | ForEach-Object { $this.GameObjects.Add([Platform]::new($_[0], $_[1], $_[2])) }
        
        #coins;
        1..8 | ForEach-Object {
            $this.GameObjects.Add([Coin]::new((Get-Random -Min 10 -Max 70), (Get-Random -Min 7 -Max 20)))
        }
        
        #enemies;
        @(
            @(30, 21, 8), @(50, 21, 6), @(30, 9, 4)
        ) | ForEach-Object { $this.GameObjects.Add([Enemy]::new($_[0], $_[1], $_[2])) }
    }
    
    [void] CreateLevel3() {
        #Ground-platforms < with gaps >;
        @(
            @(0, 22, 10), @(15, 22, 10), @(30, 22, 10), @(45, 22, 10), @(60, 22, 20)
        ) | ForEach-Object { 
            $p = [Platform]::new($_[0], $_[1], $_[2])
            $p.Color = [ConsoleColor]::Green
            $p.Symbol = [char]0x2588
            $this.GameObjects.Add($p)
        }
        
        #Vertical-challenge-platforms;
        @(
            @(5, 18, 5), @(15, 14, 5), @(25, 10, 5), @(35, 6, 5),
            @(45, 10, 5), @(55, 14, 5), @(65, 18, 5)
        ) | ForEach-Object { $this.GameObjects.Add([Platform]::new($_[0], $_[1], $_[2])) }
        
        #coins (each-platform);
        @(
            @(7, 17), @(17, 13), @(27, 9), @(37, 5),
            @(47, 9), @(57, 13), @(67, 17)
        ) | ForEach-Object { $this.GameObjects.Add([Coin]::new($_[0], $_[1])) }
        
        #Many-enemies;
        @(
            @(20, 21, 3), @(35, 21, 3), @(50, 21, 3), @(70, 21, 4)
        ) | ForEach-Object { $this.GameObjects.Add([Enemy]::new($_[0], $_[1], $_[2])) }
    }
    
    [void] Run() {
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        $this.Stopwatch.Start()
        $targetFrameTime = 1.0 / 60.0
        
        try {
            while ($this.Running) {
                $currentTime = $this.Stopwatch.Elapsed.TotalSeconds
                $deltaTime = $currentTime - $this.LastFrameTime
                
                if ($deltaTime -ge $targetFrameTime) {
                    $this.LastFrameTime = $currentTime
                    $deltaTime = [Math]::Min($deltaTime, 0.05)
                    
                    $this.ProcessInput()
                    
                    if ($this.GameState -eq 'Playing' -and -not $this.GamePaused) {
                        $this.Update($deltaTime)
                        $this.Render()
                    }
                    elseif ($this.GameState -ne 'Playing' -and -not $this.EndScreenDrawn) {
                        $this.RenderEndScreen()
                        $this.EndScreenDrawn = $true
                    }
                    elseif ($this.GamePaused) {
                        $this.RenderPauseOverlay()
                    }
                }
                
                [Thread]::Sleep(1)
            }
        }
        catch {
            Write-Host "`nGame Error: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
            Read-Host "Press Enter to continue"
        }
        finally {
            [Console]::CursorVisible = $true
            [Console]::Clear()
        }
    }
    
    [void] ProcessInput() {
        $leftPressed = $false
        $rightPressed = $false
        
        while ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            switch ($key.Key) {
                'LeftArrow' { 
                    if ($this.GameState -eq 'Playing') {
                        $leftPressed = $true
                        $this.KeyStates.Right = $false
                    }
                }
                'RightArrow' { 
                    if ($this.GameState -eq 'Playing') {
                        $rightPressed = $true
                        $this.KeyStates.Left = $false
                    }
                }
                { $_ -in 'Spacebar', 'UpArrow' } { 
                    if ($this.GameState -eq 'Playing' -and $this.Player.IsGrounded) {
                        $this.Player.Jump()
                    }
                    elseif ($this.GameState -ne 'Playing') {
                        $this.Running = $false
                    }
                }
                'Escape' { $this.Running = $false }
                'R' { 
                    if ($this.GameState -eq 'Playing') {
                        $this.RestartLevel() 
                    }
                }
                'P' { 
                    if ($this.GameState -eq 'Playing') {
                        $this.GamePaused = -not $this.GamePaused
                        if ($this.GamePaused) {
                            $this.RenderPauseOverlay()
                        }
                    }
                }
                'Enter' {
                    if ($this.GameState -ne 'Playing') {
                        $this.Running = $false
                    }
                }
            }
        }
        
        # Update < key states >;
        if ($leftPressed) { $this.KeyStates.Left = $true }
        if ($rightPressed) { $this.KeyStates.Right = $true }
        
        # Movement;
        if ($this.GameState -eq 'Playing' -and -not $this.GamePaused) {
            if ($this.KeyStates.Left) {
                $this.Player.Move(-1)
            }
            elseif ($this.KeyStates.Right) {
                $this.Player.Move(1)
            }
            else {
                $this.Player.Velocity.X *= 0.7
                if ([Math]::Abs($this.Player.Velocity.X) -lt 0.1) {
                    $this.Player.Velocity.X = 0
                }
            }
        }
        
        # Clear < key states >;
        if (-not [Console]::KeyAvailable) {
            $this.KeyStates.Left = $false
            $this.KeyStates.Right = $false
        }
    }
    
    [void] Update([double]$deltaTime) {
        # Update-timer < total-game-time >;
        if ($this.GameState -eq 'Playing' -and -not $this.GamePaused -and $this.TimerStarted) {
            $this.TotalElapsedTime = $this.Stopwatch.Elapsed.TotalSeconds - $this.GameStartTime
        }
        
        # Apply-gravity;
        if (-not $this.Player.IsGrounded) {
            $this.Player.Velocity.Y += $this.Gravity * $deltaTime
        }
        
        # Update-all-objects;
        foreach ($obj in $this.GameObjects) {
            $obj.Update($deltaTime)
        }
        
        # Handle-collisions;
        $this.HandleCollisions()
        
        # Remove-marked-objects;
        $this.GameObjects.RemoveAll({ param($obj) $obj.MarkedForRemoval })
        
        # Check < win-condition >;
        $remainingCoins = $this.GameObjects.Where({ $_ -is [Coin] -and -not $_.Collected }).Count
        if ($remainingCoins -eq 0) {
            $this.NextLevel()
        }
        
        # Check-bounds;
        if ($this.Player.Position.Y -gt $this.Height + 5) {
            $this.PlayerDeath()
        }
    }
    
    [void] HandleCollisions() {
        $this.Player.IsGrounded = $false
        $objects = $this.GameObjects.ToArray()
        
        foreach ($obj in $objects) {
            if ($obj -eq $this.Player -or $obj.MarkedForRemoval) { continue }
            
            if ($this.CheckCollision($this.Player, $obj)) {
                switch ($obj.Type) {
                    'Platform' {
                        $this.ResolvePlatformCollision($this.Player, $obj)
                    }
                    'Coin' {
                        if (-not $obj.Collected) {
                            $obj.Collected = $true
                            $obj.MarkedForRemoval = $true
                            $this.Player.Score += $obj.Value
                        }
                    }
                    'Enemy' {
                        $enemy = [Enemy]$obj
                        if (-not $enemy.IsDead) {
                            if ($this.Player.Velocity.Y -gt 0 -and $this.Player.Position.Y -lt $obj.Position.Y) {
                                $enemy.Die()
                                $this.Player.Score += 50
                                $this.Player.Velocity.Y = -15
                            }
                            else {
                                $this.PlayerDeath()
                            }
                        }
                    }
                }
            }
        }
    }
    
    [bool] CheckCollision([GameObject]$obj1, [GameObject]$obj2) {
        if ($obj2 -is [Platform]) {
            $platform = [Platform]$obj2
            return ($obj1.Position.X -ge ($platform.Position.X - 0.5) -and 
                    $obj1.Position.X -lt ($platform.Position.X + $platform.Width + 0.5) -and
                    [Math]::Abs($obj1.Position.Y - $platform.Position.Y) -lt 1.5)
        }
        else {
            return ([Math]::Abs($obj1.Position.X - $obj2.Position.X) -lt 1 -and
                    [Math]::Abs($obj1.Position.Y - $obj2.Position.Y) -lt 1)
        }
    }
    
    [void] ResolvePlatformCollision([Player]$player, [Platform]$platform) {
        $playerBottom = $player.Position.Y + 0.5
        $platformTop = $platform.Position.Y - 0.5
        
        if ($player.Velocity.Y -ge 0 -and 
            $playerBottom -ge $platformTop -and
            $player.Position.Y -lt $platform.Position.Y + 1) {
            $player.Position.Y = $platform.Position.Y - 1
            $player.Velocity.Y = 0
            $player.IsGrounded = $true
        }
    }
    
    [void] Render() {
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this.CharBuffer[$y][$x] = ' '
                $this.ColorBuffer[$y][$x] = [ConsoleColor]::Black
            }
        }

        foreach ($obj in $this.GameObjects) {
            if ($obj -is [Coin] -and $obj.Collected) { continue }
            
            $x = [int]$obj.Position.X
            $y = [int]$obj.Position.Y
            
            if ($obj -is [Platform]) {
                $platform = [Platform]$obj
                for ($i = 0; $i -lt $platform.Width; $i++) {
                    $px = $x + $i
                    if ($px -ge 0 -and $px -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
                        $this.CharBuffer[$y][$px] = $platform.Symbol
                        $this.ColorBuffer[$y][$px] = $platform.Color
                    }
                }
            }
            else {
                if ($x -ge 0 -and $x -lt $this.Width -and $y -ge 0 -and $y -lt $this.Height) {
                    $this.CharBuffer[$y][$x] = $obj.Symbol
                    $this.ColorBuffer[$y][$x] = $obj.Color
                }
            }
        }
        
        # Render-to-console;
        [Console]::SetCursorPosition(0, 0)
        
        # Status-bar:
        Write-Host "Level: $($this.Level) | " -NoNewline -ForegroundColor White
        Write-Host "Score: $($this.Player.Score)" -NoNewline -ForegroundColor Yellow
        Write-Host " | Lives: " -NoNewline -ForegroundColor White
        $livesColor = if ($this.Player.Lives -le 1) { 'Red' } else { 'Green' }
        Write-Host "$($this.Player.Lives)" -NoNewline -ForegroundColor $livesColor
        Write-Host " | Time: " -NoNewline -ForegroundColor White
        $timeColor = if ($this.TotalElapsedTime -gt $this.TotalTargetTime) { 'Red' } else { 'Cyan' }
        Write-Host ("{0:F1}s" -f $this.TotalElapsedTime) -NoNewline -ForegroundColor $timeColor
        Write-Host " | [ESC] Exit | [R] Restart | [P] Pause" -ForegroundColor Gray
        Write-Host ('-' * $this.Width) -ForegroundColor DarkGray
        
        # [ Game area ] - optimized-batch-rendering;
        $this.RenderBuffer.Clear()
        
        for ($y = 0; $y -lt $this.Height; $y++) {
            $currentColor = $this.ColorBuffer[$y][0]
            $lineStart = 0
            
            for ($x = 0; $x -le $this.Width; $x++) {
                $color = if ($x -lt $this.Width) { $this.ColorBuffer[$y][$x] } else { [ConsoleColor]::Black }
                
                if ($color -ne $currentColor -or $x -eq $this.Width) {
                    [Console]::ForegroundColor = $currentColor
                    [Console]::Write([string]::new($this.CharBuffer[$y], $lineStart, $x - $lineStart))
                    
			    if ($x -lt $this.Width) {
                        $currentColor = $color
                        $lineStart = $x
                    }
                }
            }
            
            if ($y -lt $this.Height - 1) {
                [Console]::WriteLine()
            }
        }
    }
    
    [void] RenderPauseOverlay() {
        [Console]::SetCursorPosition(35, 12)
        Write-Host " PAUSED " -ForegroundColor Black -BackgroundColor Yellow
    }
    
    [void] RenderEndScreen() {
        [Console]::Clear()
        
        if ($this.GameState -eq 'GameOver') {
            Write-Host "`n`n`n`n`n`n`n`n`n`n" -NoNewline
            Write-Host ("              GAME OVER!              ").PadLeft(50) -ForegroundColor White -BackgroundColor Red
            Write-Host "`n`n" -NoNewline
            Write-Host ("Final Score: $($this.Player.Score)").PadLeft(43) -ForegroundColor Yellow
            Write-Host "`n`n" -NoNewline
            Write-Host "Press SPACE or ENTER to exit".PadLeft(44) -ForegroundColor Gray
        }
        else {
            # Calculate < final-multiplier >;
            $baseScore = $this.Player.Score
            $finalMultiplier = 1.0
            
            if ($this.TotalElapsedTime -le $this.TotalTargetTime) {
                # Faster = higher-multiplier;
                $speedRatio = $this.TotalTargetTime / $this.TotalElapsedTime
                $finalMultiplier = [Math]::Min($speedRatio, 3.0)  # Cap < 3x-max >
            }
            else {
                # Slower = reduced-multiplier;
                $slowRatio = $this.TotalElapsedTime / $this.TotalTargetTime
                $finalMultiplier = [Math]::Max(1.0 / $slowRatio, 0.5)  # Min < 0.5x >
            }
            
            $finalScore = [int]($baseScore * $finalMultiplier)
            
            Write-Host "`n`n`n`n`n`n`n`n" -NoNewline
            Write-Host ("              VICTORY!              ").PadLeft(50) -ForegroundColor Black -BackgroundColor Green
            Write-Host "`n`n" -NoNewline
            Write-Host ("Total Time: {0:F1}s / Target: {1:F1}s" -f $this.TotalElapsedTime, $this.TotalTargetTime).PadLeft(48) -ForegroundColor Cyan
            Write-Host "`n" -NoNewline
            
            if ($this.TotalElapsedTime -le $this.TotalTargetTime) {
                Write-Host ("Speed Multiplier: {0:F1}x" -f $finalMultiplier).PadLeft(41) -ForegroundColor Magenta
            }
            else {
                Write-Host ("Speed Multiplier: {0:F1}x" -f $finalMultiplier).PadLeft(41) -ForegroundColor DarkYellow
            }
            
            Write-Host "`n" -NoNewline
            Write-Host ("Base Score: $baseScore").PadLeft(39) -ForegroundColor Gray
            Write-Host ("Final Score: $finalScore").PadLeft(40) -ForegroundColor Yellow -BackgroundColor DarkGray
            Write-Host "`n`n" -NoNewline
            Write-Host "Press SPACE or ENTER to exit".PadLeft(44) -ForegroundColor Gray
        }
    }
    
    [void] PlayerDeath() {
        $this.Player.TakeDamage()
        if ($this.Player.Lives -le 0) {
            $this.GameState = 'GameOver'
        }
        else {
            $this.RestartLevel()
        }
    }
    
    [void] RestartLevel() {
        $score = $this.Player.Score
        $lives = $this.Player.Lives
        $currentLevel = $this.Level
        $wasTimerStarted = $this.TimerStarted
        $this.InitializeLevel()
        $this.Player.Score = $score
        $this.Player.Lives = $lives
        # Preserve < timer-state >;
        $this.TimerStarted = $wasTimerStarted
    }
    
    [void] NextLevel() {
        # Level-advance;
        $this.Level++
        if ($this.Level -gt 3) {
            $this.GameState = 'Victory'
        }
        else {
            $score = $this.Player.Score
            $lives = $this.Player.Lives
            $this.InitializeLevel()
            $this.Player.Score = $score + 100  # Standard < level-completion-bonus >
            $this.Player.Lives = $lives
        }
    }
}

# Region: Main Entry Point

function Start-PlatformGame {
    [CmdletBinding()]
    param()
    
    try {
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            throw "This game requires PowerShell 5.0 or higher"
        }
        
        $originalState = @{
            Title = $Host.UI.RawUI.WindowTitle
            Background = $Host.UI.RawUI.BackgroundColor
            Foreground = $Host.UI.RawUI.ForegroundColor
        }

        $Host.UI.RawUI.WindowTitle = "ASCII Platform Game - PowerShell Edition"
        $Host.UI.RawUI.BackgroundColor = 'Black'
        $Host.UI.RawUI.ForegroundColor = 'White'
        
        try {
            $size = $Host.UI.RawUI.WindowSize
            if ($size.Width -lt 80) { $size.Width = 80 }
            if ($size.Height -lt 30) { $size.Height = 30 }
            $Host.UI.RawUI.WindowSize = $size
        }
        catch {
            # Some terminals don't support resizing.
        }
        
        Clear-Host
        Write-Host "`n" -NoNewline
        Write-Host "     ASCII PLATFORM GAME - POWERSHELL EDITION     " -ForegroundColor Black -BackgroundColor Cyan
        Write-Host "`n"
        Write-Host "CONTROLS:" -ForegroundColor Yellow
        Write-Host "  " -NoNewline; Write-Host "← →" -ForegroundColor Cyan -NoNewline; Write-Host "     Move left/right" -ForegroundColor Gray
        Write-Host "  " -NoNewline; Write-Host "SPACE" -ForegroundColor Cyan -NoNewline; Write-Host "   Jump" -ForegroundColor Gray
        Write-Host "  " -NoNewline; Write-Host "P" -ForegroundColor Cyan -NoNewline; Write-Host "       Pause game" -ForegroundColor Gray
        Write-Host "  " -NoNewline; Write-Host "R" -ForegroundColor Cyan -NoNewline; Write-Host "       Restart level" -ForegroundColor Gray
        Write-Host "  " -NoNewline; Write-Host "ESC" -ForegroundColor Cyan -NoNewline; Write-Host "     Exit game" -ForegroundColor Gray
        Write-Host "`n"
        Write-Host "OBJECTIVE:" -ForegroundColor Yellow
        Write-Host "  Collect all coins " -NoNewline -ForegroundColor Gray
        Write-Host "o" -NoNewline -ForegroundColor Yellow
        Write-Host " to advance" -ForegroundColor Gray
        Write-Host "  Avoid enemies " -NoNewline -ForegroundColor Gray
        Write-Host "X" -NoNewline -ForegroundColor Red
        Write-Host " or jump on them" -ForegroundColor Gray
        Write-Host "  Complete all 3 levels!" -ForegroundColor Gray
        Write-Host "`n"
        Write-Host "SPEEDRUN MODE:" -ForegroundColor Magenta
        Write-Host "  Complete all 3 levels as fast as possible!" -ForegroundColor Gray
        Write-Host "  Target time: 75 seconds (1:15)" -ForegroundColor Cyan
        Write-Host "  Final score multiplied by speed (up to 3x)!" -ForegroundColor Gray
        Write-Host "`n"
        Write-Host "Press any key to start..." -ForegroundColor Green
        
        $null = [Console]::ReadKey($true)
        
        # Run-game;
        $game = [GameEngine]::new()
        $game.Run()
    }
    catch {
        Write-Error "Game error: $_"
    }
    finally {
        # Restore;
        $Host.UI.RawUI.WindowTitle = $originalState.Title
        $Host.UI.RawUI.BackgroundColor = $originalState.Background
        $Host.UI.RawUI.ForegroundColor = $originalState.Foreground
        [Console]::CursorVisible = $true
        Clear-Host
    }
}

# Auto-start;
if ($MyInvocation.InvocationName -ne '.') {
    Start-PlatformGame
}
