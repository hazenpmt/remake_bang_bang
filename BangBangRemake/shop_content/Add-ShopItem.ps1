param(
    [Parameter(Mandatory = $true)][string]$ItemId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('tank','tank_skin','avatar_fashion','profile_decoration','vip_pass','material','assistant','consumable','bundle')]
    [string]$ItemType,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$ImagePath,
    [Parameter(Mandatory = $true)][string[]]$ShelfIds,
    [ValidateSet('xu','locked_xu','silver')][string]$Currency = 'xu',
    [int]$Price = 0,
    [int]$OriginalPrice = 0,
    [ValidateSet('','hot','new','sale')][string]$Badge = '',
    [string]$Description = '',
    [string]$OfferId = '',
    [int]$PurchaseLimit = 0,
    [bool]$Giftable = $true,
    [int]$RequiredLevel = 1,
    [bool]$RequiredVip = $false,
    [string]$StartAt = '',
    [string]$EndAt = '',
    [int]$SortPriority = 0,
    [string[]]$SkillImagePaths = @(),
    [string]$TankKey = '',
    [string]$SkinKey = '',
    [int]$VipDurationDays = 0,
    [int]$MaxQuantityPerOrder = 99,
    [int]$ProgressMax = 0,
    [string[]]$BundleItemIds = @(),
    [bool]$PreviewEnabled = $false
)

$ErrorActionPreference = 'Stop'
$idPattern = '^[a-z0-9_]{1,64}$'
if ($ItemId -notmatch $idPattern) {
    throw "ItemId must contain only lowercase letters, digits or underscore (1-64)."
}
if ($Price -lt 0) { throw 'Price cannot be negative.' }
if ($OriginalPrice -gt 0 -and $OriginalPrice -lt $Price) {
    throw 'OriginalPrice must be greater than or equal to Price.'
}
if ($PurchaseLimit -lt 0) { throw 'PurchaseLimit cannot be negative.' }
if ($MaxQuantityPerOrder -lt 1 -or $MaxQuantityPerOrder -gt 999) {
    throw 'MaxQuantityPerOrder must be from 1 to 999.'
}
$validShelves = @('recommend','tank','skin','fashion','decoration','vip','material','assistant')
foreach ($shelfId in $ShelfIds) {
    if ($shelfId -notin $validShelves) { throw "Invalid ShelfId: $shelfId" }
}

$grant = switch ($ItemType) {
    'tank' {
        if ($TankKey -notmatch $idPattern) { throw 'Tank requires -TankKey.' }
        [ordered]@{ kind = 'tank'; tank_key = $TankKey }
    }
    'tank_skin' {
        if ($TankKey -notmatch $idPattern -or $SkinKey -notmatch $idPattern) {
            throw 'Tank skin requires both -TankKey and -SkinKey.'
        }
        [ordered]@{ kind = 'tank_skin'; tank_key = $TankKey; skin_key = $SkinKey }
    }
    'vip_pass' {
        if ($VipDurationDays -lt 1 -or $VipDurationDays -gt 3650) {
            throw 'VIP pass requires -VipDurationDays from 1 to 3650.'
        }
        [ordered]@{ kind = 'vip'; duration_days = $VipDurationDays }
    }
    { $_ -in @('material','consumable','bundle') } {
        [ordered]@{ kind = 'inventory_stack' }
    }
    default {
        [ordered]@{ kind = 'inventory_unique' }
    }
}

$contentRoot = $PSScriptRoot
$sourceImage = (Resolve-Path -LiteralPath $ImagePath).Path
$packageRoot = Join-Path $contentRoot (Join-Path 'packages' $ItemId)
if (Test-Path -LiteralPath $packageRoot) {
    throw "Package '$ItemId' already exists: $packageRoot"
}

$assetRoot = Join-Path $packageRoot 'assets'
New-Item -ItemType Directory -Path $assetRoot | Out-Null
$imageName = [IO.Path]::GetFileName($sourceImage)
Copy-Item -LiteralPath $sourceImage -Destination (Join-Path $assetRoot $imageName)

$skillImages = @()
foreach ($skillSourcePath in $SkillImagePaths) {
    $resolvedSkill = (Resolve-Path -LiteralPath $skillSourcePath).Path
    $skillName = [IO.Path]::GetFileName($resolvedSkill)
    Copy-Item -LiteralPath $resolvedSkill -Destination (Join-Path $assetRoot $skillName)
    $skillImages += "assets/$skillName"
}

if ([string]::IsNullOrWhiteSpace($OfferId)) {
    $OfferId = "offer_$ItemId"
}
if ($OfferId -notmatch $idPattern) {
    throw "OfferId must contain only lowercase letters, digits or underscore (1-64)."
}
if ($RequiredLevel -lt 1) { throw 'RequiredLevel must be at least 1.' }
$badges = @()
if (-not [string]::IsNullOrWhiteSpace($Badge)) {
    $badges += $Badge
}

$item = [ordered]@{
    item_id = $ItemId
    item_type = $ItemType
    name = $Name
    description = $Description
    image = "assets/$imageName"
    grant = $grant
}
if ($skillImages.Count -gt 0) { $item.skills = $skillImages }
if (-not [string]::IsNullOrWhiteSpace($TankKey)) { $item.tank_key = $TankKey }
if ($ProgressMax -gt 0) {
    $item.progress = 0
    $item.progress_max = $ProgressMax
}
if ($BundleItemIds.Count -gt 0) { $item.bundle_item_ids = @($BundleItemIds) }

$offer = [ordered]@{
    offer_id = $OfferId
    item_id = $ItemId
    shelf_ids = @($ShelfIds)
    currency = $Currency
    price = $Price
    badges = $badges
    giftable = $Giftable
    required_level = $RequiredLevel
    required_vip = $RequiredVip
    sort_priority = $SortPriority
    preview_enabled = $PreviewEnabled
    max_quantity_per_order = $MaxQuantityPerOrder
    enabled = $true
}
if ($OriginalPrice -gt 0) { $offer.original_price = $OriginalPrice }
if ($PurchaseLimit -gt 0) { $offer.purchase_limit = $PurchaseLimit }
if (-not [string]::IsNullOrWhiteSpace($StartAt)) { $offer.start_at = $StartAt }
if (-not [string]::IsNullOrWhiteSpace($EndAt)) { $offer.end_at = $EndAt }

$document = [ordered]@{
    schema_version = 1
    items = @($item)
    offers = @($offer)
}

$manifestPath = Join-Path $packageRoot 'manifest.json'
$json = $document | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, $json, $utf8WithoutBom)
Write-Host "Created Shop package: $packageRoot"
Write-Host "Online server: run npm run sync-shop in BangBangServer, then reopen Shop."
