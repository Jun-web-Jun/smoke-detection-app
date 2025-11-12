# 라즈베리파이 IP 찾기 스크립트 (Windows PowerShell)

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "라즈베리파이 IP 주소 찾기" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# 현재 PC의 IP 주소 확인
Write-Host "[1/3] PC IP 주소 확인 중..." -ForegroundColor Yellow
$ipconfig = ipconfig | Select-String "IPv4" | Select-Object -First 1
Write-Host $ipconfig
Write-Host ""

# ARP 테이블에서 라즈베리파이 찾기
Write-Host "[2/3] 네트워크 장치 검색 중..." -ForegroundColor Yellow
Write-Host "ARP 테이블:" -ForegroundColor Gray
arp -a | Select-String "192.168"
Write-Host ""

# 핑 테스트
Write-Host "[3/3] 라즈베리파이 핑 테스트" -ForegroundColor Yellow
Write-Host "일반적인 IP 범위를 테스트합니다 (192.168.0.x 또는 192.168.1.x)..." -ForegroundColor Gray
Write-Host ""

$found = $false

# 192.168.0.x 범위 테스트 (처음 10개만)
Write-Host "192.168.0.x 범위 테스트 중..." -ForegroundColor Gray
1..20 | ForEach-Object {
    $ip = "192.168.0.$_"
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1
    if ($ping) {
        Write-Host "✓ $ip - 응답함!" -ForegroundColor Green
        $found = $true
    }
}

# 192.168.1.x 범위 테스트 (처음 10개만)
Write-Host "192.168.1.x 범위 테스트 중..." -ForegroundColor Gray
1..20 | ForEach-Object {
    $ip = "192.168.1.$_"
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1
    if ($ping) {
        Write-Host "✓ $ip - 응답함!" -ForegroundColor Green
        $found = $true
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
if ($found) {
    Write-Host "위에 표시된 IP 중 하나가 라즈베리파이일 가능성이 높습니다." -ForegroundColor Green
    Write-Host ""
    Write-Host "SSH 연결 시도:" -ForegroundColor Yellow
    Write-Host "  ssh pi@<IP주소>" -ForegroundColor White
    Write-Host ""
    Write-Host "예: ssh pi@192.168.0.100" -ForegroundColor Gray
} else {
    Write-Host "라즈베리파이를 찾지 못했습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "확인 사항:" -ForegroundColor Yellow
    Write-Host "  1. 라즈베리파이 전원이 켜져 있나요?" -ForegroundColor White
    Write-Host "  2. WiFi/이더넷 케이블이 연결되어 있나요?" -ForegroundColor White
    Write-Host "  3. PC와 같은 네트워크에 있나요?" -ForegroundColor White
}
Write-Host "==================================" -ForegroundColor Cyan
