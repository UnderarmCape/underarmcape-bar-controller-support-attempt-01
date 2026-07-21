[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Xbox', 'PlayStation')]
    [string]$Style,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $true)]
    [string]$PreserveDpadFrom
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PreserveDpadFrom -PathType Leaf)) { throw "D-pad source not found: $PreserveDpadFrom" }

Add-Type -AssemblyName System.Drawing

$cell = 64
$columns = 8
$rows = 5
$bitmap = New-Object Drawing.Bitmap ($cell * $columns), ($cell * $rows), ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([Drawing.Color]::Transparent)
$white = [Drawing.Color]::FromArgb(255, 255, 255, 255)
$soft = [Drawing.Color]::FromArgb(225, 255, 255, 255)
$pen = New-Object Drawing.Pen $white, 4
$pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
$thinPen = New-Object Drawing.Pen $soft, 3
$thinPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
$thinPen.EndCap = [Drawing.Drawing2D.LineCap]::Round
$brush = New-Object Drawing.SolidBrush $white
$fontLarge = New-Object Drawing.Font 'Segoe UI Semibold', 21, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$fontMedium = New-Object Drawing.Font 'Segoe UI Semibold', 14, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$fontSmall = New-Object Drawing.Font 'Segoe UI Semibold', 10, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$format = New-Object Drawing.StringFormat
$format.Alignment = [Drawing.StringAlignment]::Center
$format.LineAlignment = [Drawing.StringAlignment]::Center

function New-RoundedPath([single]$X, [single]$Y, [single]$Width, [single]$Height, [single]$Radius) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-CenteredText([string]$Text, [Drawing.Font]$Font, [single]$X, [single]$Y, [single]$Width, [single]$Height) {
    $rectangle = New-Object Drawing.RectangleF $X, $Y, $Width, $Height
    $graphics.DrawString($Text, $Font, $brush, $rectangle, $format)
}

function Draw-CircleLabel([string]$Text, [single]$X, [single]$Y) {
    $graphics.DrawEllipse($pen, $X + 11, $Y + 11, 42, 42)
    Draw-CenteredText $Text $fontLarge ($X + 11) ($Y + 9) 42 44
}

function Draw-PlayStationFace([string]$Symbol, [single]$X, [single]$Y) {
    $graphics.DrawEllipse($pen, $X + 11, $Y + 11, 42, 42)
    switch ($Symbol) {
        'cross' {
            $graphics.DrawLine($thinPen, $X + 23, $Y + 23, $X + 41, $Y + 41)
            $graphics.DrawLine($thinPen, $X + 41, $Y + 23, $X + 23, $Y + 41)
        }
        'circle' { $graphics.DrawEllipse($thinPen, $X + 22, $Y + 22, 20, 20) }
        'square' { $graphics.DrawRectangle($thinPen, $X + 23, $Y + 23, 18, 18) }
        'triangle' {
            $points = @(
                (New-Object Drawing.PointF ($X + 32), ($Y + 21)),
                (New-Object Drawing.PointF ($X + 43), ($Y + 41)),
                (New-Object Drawing.PointF ($X + 21), ($Y + 41))
            )
            $graphics.DrawPolygon($thinPen, [Drawing.PointF[]]$points)
        }
    }
}

function Draw-RoundedLabel([string]$Text, [single]$X, [single]$Y, [bool]$Tall) {
    $height = if ($Tall) { 44 } else { 30 }
    $top = $Y + (($cell - $height) / 2)
    $path = New-RoundedPath ($X + 7) $top 50 $height 8
    $graphics.DrawPath($pen, $path)
    Draw-CenteredText $Text $fontMedium ($X + 7) $top 50 $height
    $path.Dispose()
}

function Draw-XboxBumper([string]$Text, [single]$X, [single]$Y, [bool]$Right) {
    $tip = if ($Right) { $X + 55 } else { $X + 9 }
    $inner = if ($Right) { $X + 47 } else { $X + 17 }
    $points = if ($Right) {
        @((New-Object Drawing.PointF ($X + 8), ($Y + 23)), (New-Object Drawing.PointF ($X + 45), ($Y + 23)),
          (New-Object Drawing.PointF $tip, ($Y + 31)), (New-Object Drawing.PointF ($X + 45), ($Y + 41)),
          (New-Object Drawing.PointF ($X + 8), ($Y + 41)))
    } else {
        @((New-Object Drawing.PointF $inner, ($Y + 23)), (New-Object Drawing.PointF ($X + 56), ($Y + 23)),
          (New-Object Drawing.PointF ($X + 56), ($Y + 41)), (New-Object Drawing.PointF $inner, ($Y + 41)),
          (New-Object Drawing.PointF $tip, ($Y + 31)))
    }
    $graphics.DrawPolygon($pen, [Drawing.PointF[]]$points)
    Draw-CenteredText $Text $fontSmall ($X + 8) ($Y + 22) 48 20
}

function Draw-XboxTrigger([string]$Text, [single]$X, [single]$Y, [bool]$Right) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    if ($Right) {
        $path.AddBezier($X + 19, $Y + 13, $X + 39, $Y + 13, $X + 47, $Y + 22, $X + 47, $Y + 33)
        $path.AddLine($X + 47, $Y + 33, $X + 44, $Y + 52)
        $path.AddLine($X + 44, $Y + 52, $X + 22, $Y + 52)
        $path.AddBezier($X + 22, $Y + 52, $X + 17, $Y + 40, $X + 16, $Y + 24, $X + 19, $Y + 13)
    } else {
        $path.AddBezier($X + 45, $Y + 13, $X + 25, $Y + 13, $X + 17, $Y + 22, $X + 17, $Y + 33)
        $path.AddLine($X + 17, $Y + 33, $X + 20, $Y + 52)
        $path.AddLine($X + 20, $Y + 52, $X + 42, $Y + 52)
        $path.AddBezier($X + 42, $Y + 52, $X + 47, $Y + 40, $X + 48, $Y + 24, $X + 45, $Y + 13)
    }
    $path.CloseFigure()
    $graphics.DrawPath($pen, $path)
    Draw-CenteredText $Text $fontSmall ($X + 15) ($Y + 23) 34 22
    $path.Dispose()
}

function Draw-Stick([string]$Text, [single]$X, [single]$Y) {
    $graphics.DrawEllipse($pen, $X + 9, $Y + 9, 46, 46)
    $graphics.DrawEllipse($thinPen, $X + 16, $Y + 16, 32, 32)
    if (-not [string]::IsNullOrWhiteSpace($Text)) { Draw-CenteredText $Text $fontSmall ($X + 16) ($Y + 16) 32 32 }
}

function Draw-DPad([string]$Direction, [single]$X, [single]$Y) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $points = @(
        (New-Object Drawing.PointF ($X + 24), ($Y + 7)), (New-Object Drawing.PointF ($X + 40), ($Y + 7)),
        (New-Object Drawing.PointF ($X + 40), ($Y + 24)), (New-Object Drawing.PointF ($X + 57), ($Y + 24)),
        (New-Object Drawing.PointF ($X + 57), ($Y + 40)), (New-Object Drawing.PointF ($X + 40), ($Y + 40)),
        (New-Object Drawing.PointF ($X + 40), ($Y + 57)), (New-Object Drawing.PointF ($X + 24), ($Y + 57)),
        (New-Object Drawing.PointF ($X + 24), ($Y + 40)), (New-Object Drawing.PointF ($X + 7), ($Y + 40)),
        (New-Object Drawing.PointF ($X + 7), ($Y + 24)), (New-Object Drawing.PointF ($X + 24), ($Y + 24))
    )
    $path.AddPolygon([Drawing.PointF[]]$points)
    $graphics.DrawPath($thinPen, $path)
    $path.Dispose()
    if ($Direction -ne 'all') {
        $arrow = switch ($Direction) {
            'up' { @((New-Object Drawing.PointF ($X + 32), ($Y + 11)), (New-Object Drawing.PointF ($X + 25), ($Y + 21)), (New-Object Drawing.PointF ($X + 39), ($Y + 21))) }
            'down' { @((New-Object Drawing.PointF ($X + 32), ($Y + 53)), (New-Object Drawing.PointF ($X + 25), ($Y + 43)), (New-Object Drawing.PointF ($X + 39), ($Y + 43))) }
            'left' { @((New-Object Drawing.PointF ($X + 11), ($Y + 32)), (New-Object Drawing.PointF ($X + 21), ($Y + 25)), (New-Object Drawing.PointF ($X + 21), ($Y + 39))) }
            default { @((New-Object Drawing.PointF ($X + 53), ($Y + 32)), (New-Object Drawing.PointF ($X + 43), ($Y + 25)), (New-Object Drawing.PointF ($X + 43), ($Y + 39))) }
        }
        $graphics.FillPolygon($brush, [Drawing.PointF[]]$arrow)
    }
}

function Draw-Mouse([string]$Part, [single]$X, [single]$Y) {
    $path = New-RoundedPath ($X + 17) ($Y + 7) 30 50 13
    $graphics.DrawPath($pen, $path)
    $graphics.DrawLine($thinPen, $X + 17, $Y + 28, $X + 47, $Y + 28)
    $graphics.DrawLine($thinPen, $X + 32, $Y + 7, $X + 32, $Y + 28)
    if ($Part -eq 'left') { $graphics.FillRectangle($brush, $X + 21, $Y + 12, 8, 10) }
    elseif ($Part -eq 'right') { $graphics.FillRectangle($brush, $X + 35, $Y + 12, 8, 10) }
    else { $graphics.FillEllipse($brush, $X + 29, $Y + 12, 6, 12) }
    $path.Dispose()
}

function Draw-Icon([string]$Name, [single]$X, [single]$Y) {
    switch ($Name) {
        'A' { if ($Style -eq 'PlayStation') { Draw-PlayStationFace 'cross' $X $Y } else { Draw-CircleLabel 'A' $X $Y } }
        'B' { if ($Style -eq 'PlayStation') { Draw-PlayStationFace 'circle' $X $Y } else { Draw-CircleLabel 'B' $X $Y } }
        'X' { if ($Style -eq 'PlayStation') { Draw-PlayStationFace 'square' $X $Y } else { Draw-CircleLabel 'X' $X $Y } }
        'Y' { if ($Style -eq 'PlayStation') { Draw-PlayStationFace 'triangle' $X $Y } else { Draw-CircleLabel 'Y' $X $Y } }
        'LB' { if ($Style -eq 'PlayStation') { Draw-RoundedLabel 'L1' $X $Y $false } else { Draw-XboxBumper 'LB' $X $Y $false } }
        'RB' { if ($Style -eq 'PlayStation') { Draw-RoundedLabel 'R1' $X $Y $false } else { Draw-XboxBumper 'RB' $X $Y $true } }
        'LT' { if ($Style -eq 'PlayStation') { Draw-RoundedLabel 'L2' $X $Y $true } else { Draw-XboxTrigger 'LT' $X $Y $false } }
        'RT' { if ($Style -eq 'PlayStation') { Draw-RoundedLabel 'R2' $X $Y $true } else { Draw-XboxTrigger 'RT' $X $Y $true } }
        'leftStick' { Draw-Stick 'L' $X $Y } 'rightStick' { Draw-Stick 'R' $X $Y }
        'L3' { Draw-Stick 'L3' $X $Y } 'R3' { Draw-Stick 'R3' $X $Y }
        'dpad' { Draw-DPad 'all' $X $Y } 'dpadUp' { Draw-DPad 'up' $X $Y }
        'dpadDown' { Draw-DPad 'down' $X $Y } 'dpadLeft' { Draw-DPad 'left' $X $Y }
        'dpadRight' { Draw-DPad 'right' $X $Y }
        'back' {
            if ($Style -eq 'PlayStation') {
                $graphics.DrawLine($thinPen, $X + 18, $Y + 24, $X + 32, $Y + 17)
                $graphics.DrawLine($thinPen, $X + 32, $Y + 17, $X + 46, $Y + 24)
                $graphics.DrawLine($thinPen, $X + 18, $Y + 40, $X + 32, $Y + 47)
                $graphics.DrawLine($thinPen, $X + 32, $Y + 47, $X + 46, $Y + 40)
            } else {
            $graphics.DrawRectangle($thinPen, $X + 14, $Y + 22, 24, 20); $graphics.DrawRectangle($thinPen, $X + 26, $Y + 15, 24, 20)
            }
        }
        'start' {
            $graphics.DrawLine($pen, $X + 17, $Y + 21, $X + 47, $Y + 21); $graphics.DrawLine($pen, $X + 17, $Y + 32, $X + 47, $Y + 32); $graphics.DrawLine($pen, $X + 17, $Y + 43, $X + 47, $Y + 43)
        }
        'guide' {
            $points = @((New-Object Drawing.PointF ($X + 12), ($Y + 31)), (New-Object Drawing.PointF ($X + 32), ($Y + 13)), (New-Object Drawing.PointF ($X + 52), ($Y + 31)), (New-Object Drawing.PointF ($X + 47), ($Y + 31)), (New-Object Drawing.PointF ($X + 47), ($Y + 52)), (New-Object Drawing.PointF ($X + 17), ($Y + 52)), (New-Object Drawing.PointF ($X + 17), ($Y + 31)))
            $graphics.DrawPolygon($pen, [Drawing.PointF[]]$points)
        }
        'stickDirection' {
            Draw-Stick '' $X $Y; $graphics.DrawLine($pen, $X + 32, $Y + 32, $X + 49, $Y + 15); $graphics.DrawLine($pen, $X + 49, $Y + 15, $X + 39, $Y + 17); $graphics.DrawLine($pen, $X + 49, $Y + 15, $X + 47, $Y + 25)
        }
        'stickRotate' {
            $graphics.DrawArc($pen, $X + 11, $Y + 11, 42, 42, 35, 285); $graphics.DrawLine($pen, $X + 51, $Y + 24, $X + 52, $Y + 12); $graphics.DrawLine($pen, $X + 51, $Y + 24, $X + 41, $Y + 19)
        }
        'tap' { Draw-RoundedLabel 'TAP' $X $Y $false }
        'hold' { Draw-RoundedLabel 'HOLD' $X $Y $false }
        'doubleTap' { Draw-RoundedLabel '2x' $X $Y $false }
        'chord' { Draw-CenteredText '&' $fontLarge ($X + 6) ($Y + 6) 52 52 }
        'plus' { $graphics.DrawLine($pen, $X + 17, $Y + 32, $X + 47, $Y + 32); $graphics.DrawLine($pen, $X + 32, $Y + 17, $X + 32, $Y + 47) }
        'sequence' { $graphics.DrawLine($pen, $X + 13, $Y + 32, $X + 50, $Y + 32); $graphics.DrawLine($pen, $X + 50, $Y + 32, $X + 39, $Y + 21); $graphics.DrawLine($pen, $X + 50, $Y + 32, $X + 39, $Y + 43) }
        'mouseLeft' { Draw-Mouse 'left' $X $Y } 'mouseRight' { Draw-Mouse 'right' $X $Y }
        'mouseWheel' { Draw-Mouse 'wheel' $X $Y } 'mouseMiddle' { Draw-Mouse 'wheel' $X $Y }
        'keyboardKey' { Draw-RoundedLabel 'KEY' $X $Y $false }
        'dpadHorizontal' { Draw-CenteredText '< >' $fontMedium ($X + 5) ($Y + 5) 54 54 }
        'dpadVertical' { Draw-CenteredText '^ v' $fontMedium ($X + 5) ($Y + 5) 54 54 }
        'leftStickX' { Draw-Stick 'LX' $X $Y } 'leftStickY' { Draw-Stick 'LY' $X $Y }
        'rightStickX' { Draw-Stick 'RX' $X $Y } 'rightStickY' { Draw-Stick 'RY' $X $Y }
        default { Draw-CircleLabel '?' $X $Y }
    }
}

$names = @(
    'A','B','X','Y','LB','RB','LT','RT',
    'leftStick','rightStick','L3','R3','dpad','dpadUp','dpadDown','dpadLeft',
    'dpadRight','back','start','guide','stickDirection','stickRotate','tap','hold',
    'doubleTap','chord','plus','sequence','mouseLeft','mouseRight','mouseWheel','keyboardKey',
    'mouseMiddle','dpadHorizontal','dpadVertical','leftStickX','leftStickY','rightStickX','rightStickY','fallback'
)

for ($index = 0; $index -lt $names.Count; $index++) {
    Draw-Icon $names[$index] (($index % $columns) * $cell) ([math]::Floor($index / $columns) * $cell)
}

# The five v0.7 D-pad cells are immutable. Copy their pixels directly so every
# ARGB value remains identical even though the rest of each family is new.
$dpadSource = [Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $PreserveDpadFrom).Path)
$graphics.Flush()
foreach ($index in 12..16) {
    $x = ($index % $columns) * $cell
    $y = [math]::Floor($index / $columns) * $cell
    foreach ($pixelY in $y..($y + $cell - 1)) {
        foreach ($pixelX in $x..($x + $cell - 1)) {
            $bitmap.SetPixel($pixelX, $pixelY, $dpadSource.GetPixel($pixelX, $pixelY))
        }
    }
}
$dpadSource.Dispose()

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$bitmap.Save($OutputPath, [Drawing.Imaging.ImageFormat]::Png)

$format.Dispose(); $fontLarge.Dispose(); $fontMedium.Dispose(); $fontSmall.Dispose()
$brush.Dispose(); $pen.Dispose(); $thinPen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()

Write-Output ("Generated $Style controller glyph atlas with preserved v0.7 D-pad: " + (Resolve-Path -LiteralPath $OutputPath).Path)
